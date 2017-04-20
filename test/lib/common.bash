. /usr/share/makepkg/util/pkgbuild.sh

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
	local arch=$1
	local pkgver
	local pkgname
	local a
	local p
	local checkSum

	if [[ -n ${PACKAGE_CACHE} ]]; then
		checkSum=$(__getCheckSum PKGBUILD)
			# TODO: Be more specific
			if cp -av ${PACKAGE_CACHE}/${checkSum}/*-${arch}${PKGEXT}{,.sig} .; then
				return 0
			fi
	fi

	pkgname=($(. PKGBUILD; echo ${pkgname[@]}))
	pkgver=$(. PKGBUILD; get_full_version)

	if [ "${arch}" == 'any' ]; then
		makepkg -c
	else
		CARCH=${arch} makepkg -c
	fi

	for p in ${pkgname[@]}; do
		gpg --detach-sign --no-armor --use-agent ${p}-${pkgver}-${arch}*
	done

	if [[ -n ${PACKAGE_CACHE} ]]; then
		mkdir -p ${PACKAGE_CACHE}/${checkSum}
		cp -av *-${arch}${PKGEXT}{,.sig} ${PACKAGE_CACHE}/${checkSum}/
	fi
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
	local arch=$3
	local a
	local p
	local pkgver
	local pkgname

	if [ ! -d "${TMP}/svn-packages-copy/${pkgbase}/trunk" ]; then
		mkdir -p "${TMP}/svn-packages-copy/${pkgbase}"/{trunk,repos}
		cp -r "packages/${pkgbase}"/* "${TMP}/svn-packages-copy"/${pkgbase}/trunk/
		svn add -q "${TMP}/svn-packages-copy"/${pkgbase}
		svn commit -q -m"initial commit of ${pkgbase}" "${TMP}/svn-packages-copy"
	fi

	pushd "${TMP}/svn-packages-copy"/${pkgbase}/trunk/
	__buildPackage ${arch}
	archrelease -f ${repo}-${arch}
	pkgver=$(. PKGBUILD; get_full_version)
	pkgname=($(. PKGBUILD; echo ${pkgname[@]}))

	for a in ${arch[@]}; do
		for p in ${pkgname[@]}; do
			cp ${p}-${pkgver}-${a}${PKGEXT}{,.sig} "${STAGING}"/${repo}/
		done
	done

	popd
}

updatePackage() {
	local pkgbase=$1
	local arch=$2

	pushd "${TMP}/svn-packages-copy/${pkgbase}/trunk/"
	__updatePKGBUILD
	__buildPackage ${arch}
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
