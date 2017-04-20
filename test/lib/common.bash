. /usr/share/makepkg/util.sh

__getPackageBaseFromPackage() {
	local _base
	_grep_pkginfo() {
		local _ret

		_ret="$(/usr/bin/bsdtar -xOqf "$1" .PKGINFO | grep -m 1 "^${2} = ")"
		echo "${_ret#${2} = }"
	}

	_base="$(_grep_pkginfo "$1" "pkgbase")"
	if [ -z "$_base" ]; then
		_grep_pkginfo "$1" "pkgname"
	else
		echo "$_base"
	fi
}

__updatePKGBUILD() {
	local pkgrel

	pkgrel=$(. PKGBUILD; expr ${pkgrel} + 1)
	sed "s/pkgrel=.*/pkgrel=${pkgrel}/" -i PKGBUILD
	svn commit -q -m"update pkg to pkgrel=${pkgrel}"
}

__getCheckSum() {
	local result=($(sha1sum $1))
	echo ${result[0]}
}

__buildPackage() {
	local pkgdest=${1:-.}
	local p
	local cache
	local pkgarches
	local tarch
	local pkgnames

	if [[ -n ${BUILDDIR} ]]; then
		cache=${BUILDDIR}/$(__getCheckSum PKGBUILD)
		if [[ -d ${cache} ]]; then
			cp -Lv ${cache}/*${PKGEXT}{,.sig} ${pkgdest}
			return 0
		else
			mkdir -p ${cache}
		fi
	fi

	pkgarches=($(. PKGBUILD; echo ${arch[@]}))
	for tarch in ${pkgarches[@]}; do
		if [ "${tarch}" == 'any' ]; then
			PKGDEST=${pkgdest} makepkg -c
		else
			PKGDEST=${pkgdest} CARCH=${tarch} makepkg -c
		fi
	done

	pkgnames=($(. PKGBUILD; print_all_package_names))
	pushd ${pkgdest}
	for p in ${pkgnames[@]/%/${PKGEXT}}; do
		# Manually sign packages as "makepkg --sign" is buggy
		gpg -v --detach-sign --no-armor --use-agent ${p}

		if [[ -n ${BUILDDIR} ]]; then
			cp -Lv ${p}{,.sig} ${cache}/
		fi
	done
	popd
}

__archrelease() {
	local repo=$1
	local pkgarches
	local tarch
	local tag

	pkgarches=($(. PKGBUILD; echo ${arch[@]}))
	pushd ..
	for tarch in ${pkgarches[@]}; do
		tag=${repo}-${tarch}

		if [[ -d repos/$tag ]]; then
			svn rm repos/$tag/PKGBUILD
		else
			mkdir -p repos/$tag
			svn add repos/$tag
		fi

		svn copy -r HEAD trunk/PKGBUILD repos/$tag/
	done
	svn commit -m "__archrelease"
	popd
}

setup() {
	local p
	local pkg
	local r
	local a

	TMP="$(mktemp -d)"

	export DBSCRIPTS_CONFIG=${TMP}/config.local
	cat <<eot > "${DBSCRIPTS_CONFIG}"
	FTP_BASE="${TMP}/ftp"
	SVNREPO="file://${TMP}/svn-packages-repo"
	PKGREPOS=('core' 'extra' 'testing')
	PKGPOOL='pool/packages'
	SRCPOOL='sources/packages'
	TESTING_REPO='testing'
	STABLE_REPOS=('core' 'extra')
	CLEANUP_DESTDIR="${TMP}/package-cleanup"
	SOURCE_CLEANUP_DESTDIR="${TMP}/source-cleanup"
	STAGING="${TMP}/staging"
	TMPDIR="${TMP}/tmp"
	CLEANUP_DRYRUN=false
	SOURCE_CLEANUP_DRYRUN=false
eot
	. config

	mkdir -p "${TMP}/"{ftp,tmp,staging,{package,source}-cleanup,svn-packages-{copy,repo}}

	for r in ${PKGREPOS[@]}; do
		mkdir -p "${TMP}/staging/${r}"
		for a in ${ARCHES[@]}; do
			mkdir -p "${TMP}/ftp/${r}/os/${a}"
		done
	done
	mkdir -p "${TMP}/ftp/${PKGPOOL}"
	mkdir -p "${TMP}/ftp/${SRCPOOL}"

	svnadmin create "${TMP}/svn-packages-repo"
	svn checkout -q "file://${TMP}/svn-packages-repo" "${TMP}/svn-packages-copy"
}

teardown() {
	rm -rf "${TMP}"
}

releasePackage() {
	local repo=$1
	local pkgbase=$2

	if [ ! -d "${TMP}/svn-packages-copy/${pkgbase}/trunk" ]; then
		mkdir -p "${TMP}/svn-packages-copy/${pkgbase}"/{trunk,repos}
		cp -r "packages/${pkgbase}"/* "${TMP}/svn-packages-copy"/${pkgbase}/trunk/
		svn add -q "${TMP}/svn-packages-copy"/${pkgbase}
		svn commit -q -m"initial commit of ${pkgbase}" "${TMP}/svn-packages-copy"
	fi

	pushd "${TMP}/svn-packages-copy"/${pkgbase}/trunk/
	__buildPackage "${STAGING}"/${repo}
	__archrelease ${repo}
	popd
}

updatePackage() {
	local pkgbase=$1

	pushd "${TMP}/svn-packages-copy/${pkgbase}/trunk/"
	__updatePKGBUILD
	__buildPackage
	popd
}

updateRepoPKGBUILD() {
	local pkgbase=$1
	local repo=$2
	local arch=$3

	pushd "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}/"
	__updatePKGBUILD
	popd
}

getPackageNamesFromPackageBase() {
	local pkgbase=$1

	$(. "packages/${pkgbase}/PKGBUILD"; echo ${pkgname[@]})
}

checkPackageDB() {
	local repo=$1
	local pkg=$2
	local arch=$3
	local db
	local tarch
	local tarches

	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}" ]
	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ]
	[ ! -r "${STAGING}"/${repo}/${pkg} ]
	[ ! -r "${STAGING}"/${repo}/${pkg}.sig ]

	if [[ $arch == any ]]; then
		tarches=(${ARCHES[@]})
	else
		tarches=(${arch})
	fi

	for tarch in ${tarches[@]}; do
		[ -L "${FTP_BASE}/${repo}/os/${tarch}/${pkg}" ]
		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${tarch}/${pkg}")" == "${FTP_BASE}/${PKGPOOL}/${pkg}" ]

		[ -L "${FTP_BASE}/${repo}/os/${tarch}/${pkg}.sig" ]
		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${tarch}/${pkg}.sig")" == "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ]

		for db in ${DBEXT} ${FILESEXT}; do
			[ -r "${FTP_BASE}/${repo}/os/${tarch}/${repo}${db%.tar.*}" ]
			bsdtar -xf "${FTP_BASE}/${repo}/os/${tarch}/${repo}${db%.tar.*}" -O | grep -q ${pkg}
		done
	done
}

checkPackage() {
	local repo=$1
	local pkg=$2
	local arch=$3

	checkPackageDB $repo $pkg $arch

	local pkgbase=$(__getPackageBaseFromPackage "${FTP_BASE}/${PKGPOOL}/${pkg}")
	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}" ]
}

checkRemovedPackage() {
	local repo=$1
	local pkgbase=$2
	local arch=$3

	checkRemovedPackageDB $repo $pkgbase $arch

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ ! -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}" ]
}

checkRemovedPackageDB() {
	local repo=$1
	local pkgbase=$2
	local arch=$3
	local db
	local tarch
	local tarches

	if [[ $arch == any ]]; then
		tarches=(${ARCHES[@]})
	else
		tarches=(${arch})
	fi

	for db in ${DBEXT} ${FILESEXT}; do
		for tarch in ${tarches[@]}; do
			if [ -r "${FTP_BASE}/${repo}/os/${tarch}/${repo}${db%.tar.*}" ]; then
				echo "$(bsdtar -xf "${FTP_BASE}/${repo}/os/${tarch}/${repo}${db%.tar.*}" -O)" | grep -qv ${pkgbase}
			fi
		done
	done
}
