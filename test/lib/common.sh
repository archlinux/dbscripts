oneTimeSetUp() {
	local d

	pkgdir="$(mktemp -d)"
	cp -Lr $(dirname ${BASH_SOURCE[0]})/../packages/* "${pkgdir}"
	for d in "${pkgdir}"/*; do
		pushd $d >/dev/null
		buildPackage
		popd >/dev/null
	done
}

oneTimeTearDown() {
	rm -rf "${pkgdir}"
}

setUp() {
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
	. "$(dirname ${BASH_SOURCE[0]})/../../config"

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

	for p in "${pkgdir}"/*; do
		pkg=${p##*/}
		mkdir -p "${TMP}/svn-packages-copy/${pkg}"/{trunk,repos}
		cp "${p}"/* "${TMP}/svn-packages-copy"/${pkg}/trunk/
		svn add -q "${TMP}/svn-packages-copy"/${pkg}
		svn commit -q -m"initial commit of ${pkg}" "${TMP}/svn-packages-copy"
	done
}

tearDown() {
	rm -rf "${TMP}"
}

getpkgbase() {
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

releasePackage() {
	local repo=$1
	local pkgbase=$2
	local arch=$3
	local a
	local p
	local pkgver
	local pkgname

	pushd "${TMP}/svn-packages-copy"/${pkgbase}/trunk/ >/dev/null
	archrelease ${repo}-${arch} >/dev/null 2>&1
	pkgver=$(. PKGBUILD; get_full_version)
	pkgname=($(. PKGBUILD; echo ${pkgname[@]}))

	for a in ${arch[@]}; do
		for p in ${pkgname[@]}; do
			cp ${p}-${pkgver}-${a}${PKGEXT}{,.sig} "${STAGING}"/${repo}/
		done
	done

	popd >/dev/null
}

buildPackage() {
	local pkgarch
	local pkgver
	local pkgname
	local a
	local p

	pkgname=($(. PKGBUILD; echo ${pkgname[@]}))
	pkgver=$(. PKGBUILD; get_full_version)
	pkgarch=($(. PKGBUILD; echo ${arch[@]}))

	if [ "${pkgarch[0]}" == 'any' ]; then
		makepkg -cCf || fail 'makepkg failed'
	else
		for a in ${pkgarch[@]}; do
			CARCH=${a} makepkg -cCf || fail "makepkg failed"
		done
	fi

	for a in ${pkgarch[@]}; do
		for p in ${pkgname[@]}; do
			gpg --detach-sign --no-armor --use-agent ${p}-${pkgver}-${a}* || fail 'gpg failed'
		done
	done
}

__updatePKGBUILD() {
	local pkgrel

	pkgrel=$(. PKGBUILD; expr ${pkgrel} + 1)
	sed "s/pkgrel=.*/pkgrel=${pkgrel}/" -i PKGBUILD
	svn commit -q -m"update pkg to pkgrel=${pkgrel}" >/dev/null
}

updatePackage() {
	local pkgbase=$1

	pushd "${TMP}/svn-packages-copy/${pkgbase}/trunk/" >/dev/null
	__updatePKGBUILD
	buildPackage
	popd >/dev/null
}

updateRepoPKGBUILD() {
	local pkgbase=$1
	local repo=$2
	local arch=$3

	pushd "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}/" >/dev/null
	__updatePKGBUILD
	popd >/dev/null
}

checkAnyPackageDB() {
	local repo=$1
	local pkg=$2
	local arch
	local db

	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}" ] || fail "${PKGPOOL}/${pkg} not found"
	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ] || fail "${PKGPOOL}/${pkg}.sig not found"

	for arch in i686 x86_64; do
		[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ] || fail "${repo}/os/${arch}/${pkg} is not a symlink"
		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}")" == "${FTP_BASE}/${PKGPOOL}/${pkg}" ] \
			|| fail "${repo}/os/${arch}/${pkg} does not link to ${PKGPOOL}/${pkg}"

		[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig" ] || fail "${repo}/os/${arch}/${pkg}.sig is not a symlink"
		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig")" == "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ] \
			|| fail "${repo}/os/${arch}/${pkg}.sig does not link to ${PKGPOOL}/${pkg}.sig"

		for db in ${DBEXT} ${FILESEXT}; do
			( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" ] \
				&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" -O | grep -q ${pkg}) \
				|| fail "${pkg} not in ${repo}/os/${arch}/${repo}${db%.tar.*}"
		done
	done
	[ -r "${STAGING}"/${repo}/${pkg} ] && fail "${repo}/${pkg} found in staging dir"
	[ -r "${STAGING}"/${repo}/${pkg}.sig ] && fail "${repo}/${pkg}.sig found in staging dir"
}

checkAnyPackage() {
	local repo=$1
	local pkg=$2

	checkAnyPackageDB $repo $pkg

	local pkgbase=$(getpkgbase "${FTP_BASE}/${PKGPOOL}/${pkg}")
	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-any" ] \
		|| fail "svn-packages-copy/${pkgbase}/repos/${repo}-any does not exist"
}

checkPackageDB() {
	local repo=$1
	local pkg=$2
	local arch=$3
	local db

	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}" ] || fail "${PKGPOOL}/${pkg} not found"
	[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ] || fail "${repo}/os/${arch}/${pkg} not a symlink"
	[ -r "${STAGING}"/${repo}/${pkg} ] && fail "${repo}/${pkg} found in staging dir"

	[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}")" == "${FTP_BASE}/${PKGPOOL}/${pkg}" ] \
		|| fail "${repo}/os/${arch}/${pkg} does not link to ${PKGPOOL}/${pkg}"

	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ] || fail "${PKGPOOL}/${pkg}.sig not found"
	[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig" ] || fail "${repo}/os/${arch}/${pkg}.sig is not a symlink"
	[ -r "${STAGING}"/${repo}/${pkg}.sig ] && fail "${repo}/${pkg}.sig found in staging dir"

	[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig")" == "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ] \
		|| fail "${repo}/os/${arch}/${pkg}.sig does not link to ${PKGPOOL}/${pkg}.sig"

	for db in ${DBEXT} ${FILESEXT}; do
		( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" ] \
			&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" -O | grep -q ${pkg}) \
			|| fail "${pkg} not in ${repo}/os/${arch}/${repo}${db%.tar.*}"
	done
}

checkPackage() {
	local repo=$1
	local pkg=$2
	local arch=$3

	checkPackageDB $repo $pkg $arch

	local pkgbase=$(getpkgbase "${FTP_BASE}/${PKGPOOL}/${pkg}")
	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}" ] \
		|| fail "svn-packages-copy/${pkgbase}/repos/${repo}-${arch} does not exist"
}

checkRemovedPackageDB() {
	local repo=$1
	local pkgbase=$2
	local arch=$3
	local db

	for db in ${DBEXT} ${FILESEXT}; do
		( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" ] \
			&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" -O | grep -q ${pkgbase}) \
			&& fail "${pkgbase} should not be in ${repo}/os/${arch}/${repo}${db%.tar.*}"
	done
}

checkRemovedPackage() {
	local repo=$1
	local pkgbase=$2
	local arch=$3

	checkRemovedPackageDB $repo $pkgbase $arch

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}" ] \
		&& fail "svn-packages-copy/${pkgbase}/repos/${repo}-${arch} should not exist"
}

checkRemovedAnyPackageDB() {
	local repo=$1
	local pkgbase=$2
	local arch
	local db

	for db in ${DBEXT} ${FILESEXT}; do
		for arch in i686 x86_64; do
			( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" ] \
				&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" -O | grep -q ${pkgbase}) \
				&& fail "${pkgbase} should not be in ${repo}/os/${arch}/${repo}${db%.tar.*}"
		done
	done
}

checkRemovedAnyPackage() {
	local repo=$1
	local pkgbase=$2

	checkRemovedAnyPackageDB $repo $pkgbase

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-any" ] \
		&& fail "svn-packages-copy/${pkgbase}/repos/${repo}-any should not exist"
}
