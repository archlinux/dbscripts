. /usr/share/makepkg/util.sh
shopt -s extglob

__updatePKGBUILD() {
	local pkgrel

	pkgrel=$(. PKGBUILD; expr ${pkgrel} + 1)
	sed "s/pkgrel=.*/pkgrel=${pkgrel}/" -i PKGBUILD
	svn commit -q -m"update pkg to pkgrel=${pkgrel}"
}

__getCheckSum() {
	local result
	result="$(sha1sum "$1")"
	echo "${result%% *}"
}

# Proxy function to check if a file exists. Using [[ -f ... ]] directly is not
# always wanted because we might want to expand bash globs first. This way we
# can pass unquoted globs to __isGlobfile() and have them expanded as function
# arguments before being checked.
#
# This is a copy of db-functions is_globfile
__isGlobfile() {
	[[ -f $1 ]]
}

__buildPackage() {
	local pkgdest=${1:-.}
	local p
	local cache
	local pkgarches
	local tarch
	local pkgfiles

	if [[ -n ${BUILDDIR} ]]; then
		cache=${BUILDDIR}/$(__getCheckSum PKGBUILD)
		if cp -Lv ${cache}/*${PKGEXT}{,.sig} ${pkgdest} 2>/dev/null; then
			return 0
		else
			mkdir -p ${cache}
		fi
	fi

	pkgarches=($(. PKGBUILD; echo ${arch[@]}))
	for tarch in ${pkgarches[@]}; do
		if [ "${tarch}" == 'any' ]; then
			PKGDEST=${pkgdest} PKGEXT=${PKGEXT} makepkg -c
			mapfile -tO "${#pkgfiles[@]}" pkgfiles < <(PKGDEST=${pkgdest} PKGEXT=${PKGEXT} makepkg --packagelist)
		else
			PKGDEST=${pkgdest} PKGEXT=${PKGEXT} CARCH=${tarch} makepkg -c
			mapfile -tO "${#pkgfiles[@]}" pkgfiles < <(PKGDEST=${pkgdest} PKGEXT=${PKGEXT} CARCH=${tarch} makepkg --packagelist)
		fi
	done

	for p in ${pkgfiles[@]}; do
		# Manually sign packages as "makepkg --sign" is buggy
		gpg -v --detach-sign --no-armor --use-agent ${p}

		if [[ -n ${BUILDDIR} ]]; then
			cp -Lv ${p}{,.sig} ${cache}/
		fi
	done
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
	PKGEXT=".pkg.tar.xz"

	TMP="$(mktemp -d)"

	export DBSCRIPTS_CONFIG=${TMP}/config.local
	cat <<eot > "${DBSCRIPTS_CONFIG}"
	FTP_BASE="${TMP}/ftp"
	ARCHIVE_BASE="${TMP}/archive"
	ARCHIVEUSER=""
	SVNREPO="file://${TMP}/svn-packages-repo"
	PKGREPOS=('core' 'extra' 'testing')
	PKGPOOL='pool/packages'
	SRCPOOL='sources/packages'
	STAGING_REPOS=('staging')
	TESTING_REPOS=('testing')
	STABLE_REPOS=('core' 'extra')
	CLEANUP_DESTDIR="${TMP}/package-cleanup"
	SOURCE_CLEANUP_DESTDIR="${TMP}/source-cleanup"
	STAGING="${TMP}/staging"
	TMPDIR="${TMP}/tmp"
	ARCHES=(x86_64 i686)
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

	# make dummy packages for "reproducibility"
	pacman -Qq | pacman -Sddp - | while read -r line; do
		line=${line##*/}
		pkgname=${line%-*-*-*}
		mkdir -p "${ARCHIVE_BASE}/packages/${pkgname:0:1}/${pkgname}"
		touch "${ARCHIVE_BASE}/packages/${pkgname:0:1}/${pkgname}/${line}"{,.sig}
	done

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
		cp -r "fixtures/${pkgbase}"/* "${TMP}/svn-packages-copy"/${pkgbase}/trunk/
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

checkPackageDB() {
	local repo=$1
	local pkgbase=$2
	local pkgver=$3
	local db
	local pkgarch
	local repoarch
	local repoarches
	local pkgfile
	local pkgname

	local pkgarches=($(. "fixtures/$pkgbase/PKGBUILD"; echo ${arch[@]}))
	local pkgnames=($(. "fixtures/$pkgbase/PKGBUILD"; echo ${pkgname[@]}))

	if [[ ${pkgarches[@]} == any ]]; then
		repoarches=(${ARCHES[@]})
	else
		repoarches=(${pkgarches[@]})
	fi

	for pkgarch in ${pkgarches[@]}; do
		for pkgname in ${pkgnames[@]}; do
			pkgfile="${pkgname}-${pkgver}-${pkgarch}${PKGEXT}"

			[ -r ${FTP_BASE}/${PKGPOOL}/${pkgfile} ]
			[ -r ${FTP_BASE}/${PKGPOOL}/${pkgfile}.sig ]
			[ ! -r ${STAGING}/${repo}/${pkgfile} ]
			[ ! -r ${STAGING}/${repo}/${pkgfile}.sig ]

			for repoarch in ${repoarches[@]}; do
				# Only 'any' packages can be found in repos of both arches
				if [[ $pkgarch != any ]]; then
					if [[ $pkgarch != ${repoarch} ]]; then
						continue
					fi
				fi

				[ -L ${FTP_BASE}/${repo}/os/${repoarch}/${pkgfile} ]
				[ "$(readlink -e ${FTP_BASE}/${repo}/os/${repoarch}/${pkgfile})" == ${FTP_BASE}/${PKGPOOL}/${pkgfile} ]

				[ -L ${FTP_BASE}/${repo}/os/${repoarch}/${pkgfile}.sig ]
				[ "$(readlink -e ${FTP_BASE}/${repo}/os/${repoarch}/${pkgfile}.sig)" == ${FTP_BASE}/${PKGPOOL}/${pkgfile}.sig ]

				for db in ${DBEXT} ${FILESEXT}; do
					[ -r "${FTP_BASE}/${repo}/os/${repoarch}/${repo}${db%.tar.*}" ]
					bsdtar -xf "${FTP_BASE}/${repo}/os/${repoarch}/${repo}${db%.tar.*}" -O | grep "${pkgfile%${PKGEXT}}" &>/dev/null
				done
			done
		done
	done
}

checkPackage() {
	local repo=$1
	local pkgbase=$2
	local pkgver=$3

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"

	local dirarches=() pkgbuildarches=()
	local pkgbuild dirarch pkgbuildver
	for pkgbuild in "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-"+([^-])"/PKGBUILD"; do
		[[ -e $pkgbuild ]] || continue
		dirarch=${pkgbuild%/PKGBUILD}
		dirarch=${dirarch##*-}

		dirarches+=("$dirarch")
		pkgbuildarches+=($(. "$pkgbuild"; echo ${arch[@]}))
		pkgbuildver=$(. "$pkgbuild"; get_full_version)
		[[ $pkgver = "$pkgbuildver" ]]
	done
	# Verify that the arches-from-dirnames and
	# arches-from-PKGBUILDs agree (that a PKGBUILD existed for
	# every arch).
	(( ${#dirarches[@]} > 0 ))
	mapfile -d '' dirarches      < <(printf '%s\0' "${dirarches[@]}"      | sort -uz)
	mapfile -d '' pkgbuildarches < <(printf '%s\0' "${pkgbuildarches[@]}" | sort -uz)
	declare -p dirarches pkgbuildarches
	[[ "${dirarches[*]}" = "${pkgbuildarches[*]}" ]]

	checkPackageDB "$repo" "$pkgbase" "$pkgver"
}

checkRemovedPackage() {
	local repo=$1
	local pkgbase=$2

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"

	if __isGlobfile "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-"+([^-])"/PKGBUILD"; then
		return 1
	fi

	checkRemovedPackageDB $repo $pkgbase
}

checkRemovedPackageDB() {
	local repo=$1
	local pkgbase=$2
	local arch
	local db
	local tarch
	local tarches
	local pkgarches
	local pkgnames
	local pkgname

	pkgarches=($(. "fixtures/$pkgbase/PKGBUILD"; echo ${arch[@]}))
	pkgnames=($(. "fixtures/$pkgbase/PKGBUILD"; echo ${pkgname[@]}))

	if [[ ${pkgarches[@]} == any ]]; then
		tarches=(${ARCHES[@]})
	else
		tarches=(${pkgarches[@]})
	fi

	for db in ${DBEXT} ${FILESEXT}; do
		for tarch in ${tarches[@]}; do
			if [ -r "${FTP_BASE}/${repo}/os/${tarch}/${repo}${db%.tar.*}" ]; then
				for pkgname in ${pkgnames[@]}; do
					if bsdtar -xf "${FTP_BASE}/${repo}/os/${tarch}/${repo}${db%.tar.*}" -O | grep ${pkgname} &>/dev/null; then
						return 1
					fi
				done
			fi
		done
	done
}
