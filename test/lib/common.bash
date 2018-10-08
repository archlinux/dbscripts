. /usr/share/makepkg/util.sh
shopt -s extglob

__updatePKGBUILD() {
	local pkgrel

	pkgrel=$(. PKGBUILD; expr ${pkgrel} + 1)
	sed "s/pkgrel=.*/pkgrel=${pkgrel}/" -i PKGBUILD
	vcsCommit "update pkg to pkgrel=${pkgrel}"
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
	PKGREPOS=('core' 'extra' 'testing')
	PKGPOOL='pool/packages'
	SRCPOOL='sources/packages'
	TESTING_REPO='testing'
	STABLE_REPOS=('core' 'extra')
	CLEANUP_DESTDIR="${TMP}/package-cleanup"
	SOURCE_CLEANUP_DESTDIR="${TMP}/source-cleanup"
	STAGING="${TMP}/staging"
	TMPDIR="${TMP}/tmp"
	ARCHES=(x86_64 i686)
	CLEANUP_DRYRUN=false
	SOURCE_CLEANUP_DRYRUN=false
eot
	. "lib/common-$(. config; echo "$VCS").bash"
	vcsSetup
	. config

	mkdir -p "${TMP}/"{ftp,tmp,staging,{package,source}-cleanup}

	for r in ${PKGREPOS[@]}; do
		mkdir -p "${TMP}/staging/${r}"
		for a in ${ARCHES[@]}; do
			mkdir -p "${TMP}/ftp/${r}/os/${a}"
		done
	done
	mkdir -p "${TMP}/ftp/${PKGPOOL}"
	mkdir -p "${TMP}/ftp/${SRCPOOL}"
}

teardown() {
	rm -rf "${TMP}"
}

releasePackage() {
	local repo=$1
	local pkgbase=$2

	local dir=$(vcsDirOfPKGBUILD "$pkgbase")

	if [[ ! -d $dir ]]; then
		vcsInitFixture "$pkgbase"
	fi

	pushd "$dir"
	__buildPackage "${STAGING}"/${repo}
	vcsRelease ${repo}
	popd
}

updatePackage() {
	local pkgbase=$1

	pushd "$(vcsDirOfPKGBUILD "$pkgbase")"
	__updatePKGBUILD
	__buildPackage
	popd
}

updateRepoPKGBUILD() {
	local pkgbase=$1
	local repo=$2

	# Update the PKGBUILD and release the PKGBUILD, but *without*
	# ever building or releasing the binary package.
	pushd "$(vcsDirOfPKGBUILD "$pkgbase")"
	__updatePKGBUILD
	vcsRelease ${repo}
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

	vcsCheckPackage "$repo" "$pkgbase" "$pkgver"

	checkPackageDB "$repo" "$pkgbase" "$pkgver"
}

checkRemovedPackage() {
	local repo=$1
	local pkgbase=$2

	vcsCheckRemovedPackage "$repo" "$pkgbase"

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
