set -E

. "${curdir}/../db-functions"

oneTimeSetUp() {
	local p
	pkgdir="$(mktemp -d /dev/shm/$(basename $0).XXXXXXXXXX)"
	cp -r ${curdir}/packages/* "${pkgdir}"
	msg 'Building packages...'
	for p in "${pkgdir}"/*; do
		pushd $p >/dev/null
		linux32 makepkg -cf --config ${curdir}/lib/makepkg-i686.conf >/dev/null 2>&1 || die 'makepkg failed'
		[ -f *-any.pkg.tar.* ] \
			|| linux64 makepkg -cf --config ${curdir}/lib/makepkg-x86_64.conf >/dev/null 2>&1 \
			|| die 'makepkg failed'
		popd >/dev/null
	done
	echo
}

oneTimeTearDown() {
	rm -rf "${pkgdir}"
}

setUp() {
	local p
	local pkg

	#[ -f "${curdir}/../config.local" ] && die "${curdir}/../config.local exists"
	TMP="$(mktemp -d /dev/shm/$(basename $0).XXXXXXXXXX)"
	#msg "Using ${TMP}"

	mkdir -p "${TMP}/"{ftp,tmp,staging,{package,source}-cleanup,svn-{packages,community}-{copy,repo}}
	mkdir -p "${TMP}/ftp/"{core,extra,community,testing,community-testing}/os/{i686,any,x86_64}
	mkdir -p "${TMP}/ftp/pool/"{packages,community}
	mkdir -p "${TMP}/staging/"{core,extra,community,testing,community-testing}

	msg 'Creating svn repository...'
	svnadmin create "${TMP}/svn-packages-repo"
	svnadmin create "${TMP}/svn-community-repo"
	svn checkout -q "file://${TMP}/svn-packages-repo" "${TMP}/svn-packages-copy"
	svn checkout -q "file://${TMP}/svn-community-repo" "${TMP}/svn-community-copy"

	for p in "${pkgdir}"/*; do
		pkg=$(basename $p)
		mkdir -p "${TMP}/svn-packages-copy/${pkg}"/{trunk,repos}
		cp "${p}/PKGBUILD" "${TMP}/svn-packages-copy"/${pkg}/trunk/
		svn add -q "${TMP}/svn-packages-copy"/${pkg}
		svn commit -q -m"initial commit of ${pkg}" "${TMP}/svn-packages-copy"
	done

	cat <<eot > "${curdir}/../config.local"
	FTP_BASE="${TMP}/ftp"
	SVNREPO="file://${TMP}/svn-packages-repo"
	SVNREPOCOMMUNITY="file://${TMP}/svn-community-repo"
	CLEANUP_DESTDIR="${TMP}/package-cleanup"
	SOURCE_CLEANUP_DESTDIR="${TMP}/source-cleanup"
	STAGING="${TMP}/staging"
	TMPDIR="${TMP}/tmp"
	CLEANUP_DRYRUN=false
eot
	. "${curdir}/../config"
}

tearDown() {
	rm -rf "${TMP}"
	rm -f "${curdir}/../config.local"
	echo
}

releasePackage() {
	local repo=$1
	local pkgbase=$2
	local arch=$3

	pushd "${TMP}/svn-packages-copy"/${pkgbase}/trunk/ >/dev/null
	archrelease ${repo}-${arch} >/dev/null 2&>1
	pkgver=$(. PKGBUILD; echo "${pkgver}-${pkgrel}")
	popd >/dev/null
	cp "${pkgdir}/${pkgbase}"/*-${pkgver}-${arch}.pkg.tar.* "${STAGING}"/${repo}/
}

checkAnyPackage() {
	local repo=$1
	local pkg=$2
	local arch

	[ -r "${FTP_BASE}/$(get_pkgpool_for_host)/${pkg}" ] || fail "$(get_pkgpool_for_host)/${pkg} not found"

	for arch in i686 x86_64; do
		[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ] || fail "${repo}/os/${arch}/${pkg} not a symlink"
		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}")" == "${FTP_BASE}/$(get_pkgpool_for_host)/${pkg}" ] \
			|| fail "${repo}/os/${arch}/${pkg} does not link to $(get_pkgpool_for_host)/${pkg}"
	done
	[ -r "${STAGING}"/${repo}/${pkg} ] && fail "${repo}/${pkg} found in staging dir"

	( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" ] \
		&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" -O | grep -q ${pkg}) \
		|| fail "${pkg} not in ${repo}/os/${arch}/${repo}${DBEXT%.tar.*}"

	[ -r "${FTP_BASE}/${repo}/os/any/${pkg}" ] && fail "${repo}/os/any/${pkg} should not exist"
}

checkPackage() {
	local repo=$1
	local pkg=$2
	local arch=$3

	[ -r "${FTP_BASE}/$(get_pkgpool_for_host)/${pkg}" ] || fail "$(get_pkgpool_for_host)/${pkg} not found"
	[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ] || fail "${repo}/os/${arch}/${pkg} not a symlink"
	[ -r "${STAGING}"/${repo}/${pkg} ] && fail "${repo}/${pkg} found in staging dir"

	[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}")" == "${FTP_BASE}/$(get_pkgpool_for_host)/${pkg}" ] \
		|| fail "${repo}/os/${arch}/${pkg} does not link to $(get_pkgpool_for_host)/${pkg}"

	( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" ] \
		&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" -O | grep -q ${pkg}) \
		|| fail "${pkg} not in ${repo}/os/${arch}/${repo}${DBEXT%.tar.*}"

	local pkgbase=$(getpkgbase "${FTP_BASE}/$(get_pkgpool_for_host)/${pkg}")
	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}" ] \
		|| fail "svn-packages-copy/${pkgbase}/repos/${repo}-${arch} does not exist"
}

checkRemovedPackage() {
	local repo=$1
	local pkgbase=$2
	local arch=$3

	( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" ] \
		&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" -O | grep -q ${pkgbase}) \
		&& fail "${pkgbase} should not be in ${repo}/os/${arch}/${repo}${DBEXT%.tar.*}"

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}" ] \
		&& fail "svn-packages-copy/${pkgbase}/repos/${repo}-${arch} should not exist"
}

checkRemovedAnyPackage() {
	local repo=$1
	local pkgbase=$2
	local arch

	for arch in i686 x86_64; do
		( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" ] \
			&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" -O | grep -q ${pkgbase}) \
			&& fail "${pkgbase} should not be in ${repo}/os/${arch}/${repo}${DBEXT%.tar.*}"
	done

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-any" ] \
		&& fail "svn-packages-copy/${pkgbase}/repos/${repo}-any should not exist"
}
