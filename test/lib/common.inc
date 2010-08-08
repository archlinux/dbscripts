. "${curdir}/../db-functions"

oneTimeSetUp() {
	local p
	pkgdir="$(mktemp -d /dev/shm/$(basename $0).XXXXXXXXXX)"
	cp -r ${curdir}/packages/* "${pkgdir}"
	echo -n 'Building packages...'
	for p in "${pkgdir}"/*; do
		pushd $p >/dev/null
		linux32 makepkg -cf --config ${curdir}/lib/makepkg-i686.conf >/dev/null 2>&1 || exit 1
		[ -f *-any.pkg.tar.* ] || linux64 makepkg -cf --config ${curdir}/lib/makepkg-x86_64.conf >/dev/null 2>&1 || exit 1
		popd >/dev/null
	done
	echo 'done'
	echo
}

oneTimeTearDown() {
	rm -rf "${pkgdir}"
}

setUp() {
	local p
	local pkg

	[ -f "${curdir}/../config.local" ] && exit 1
	TMP="$(mktemp -d /dev/shm/$(basename $0).XXXXXXXXXX)"
	#echo "Using ${TMP}"

	mkdir -p "${TMP}/"{ftp,tmp,staging,{package,source}-cleanup,svn-{packages,community}-{copy,repo}}
	mkdir -p "${TMP}/ftp/"{{core,extra,community,testing,community-testing}/os,packages/{arch,community}}/{i686,any,x86_64}
	mkdir -p "${TMP}/staging/"{core,extra,community,testing,community-testing}

	echo -n 'Creating svn repository...'
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
	echo 'done'

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
	popd >/dev/null
	cp "${pkgdir}/${pkgbase}"/*.pkg.tar.* "${STAGING}"/${repo}/
}

checkAnyPackage() {
	local repo=$1
	local pkg=$2
	local arch

	[ -f "${FTP_BASE}/packages/arch/any/${pkg}" ] || fail "packages/arch/any/${pkg} not found"

	for arch in i686 x86_64; do
		[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ] || fail "${repo}/os/${arch}/${pkg} not a symlink"
		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}")" == "${FTP_BASE}/packages/arch/any/${pkg}" ] || fail "${repo}/os/${arch}/${pkg} does not link to packages/arch/any/${pkg}"
	done
	[ -f "${STAGING}"/${repo}/${pkg} ] && fail "${repo}/${pkg} found in staging dir"

	bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}.db.tar.gz" -O | grep -q ${pkg} || fail "${pkg} not in ${repo}/os/${arch}/${repo}.db.tar.gz"

	[ -f "${FTP_BASE}/${repo}/os/any/${pkg}" ] && fail "${repo}/os/any/${pkg} should not exist"
}

checkPackage() {
	local repo=$1
	local pkg=$2
	local arch=$3

	[ -f "${FTP_BASE}/packages/arch/${arch}/${pkg}" ] || fail "packages/arch/${arch}/${pkg} not found"
	[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ] || fail "${repo}/os/${arch}/${pkg} not a symlink"
	[ -f "${STAGING}"/${repo}/${pkg} ] && fail "${repo}/${pkg} found in staging dir"

	[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}")" == "${FTP_BASE}/packages/arch/${arch}/${pkg}" ] || fail "${repo}/os/${arch}/${pkg} does not link to packages/arch/${arch}/${pkg}"

	bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}.db.tar.gz" -O | grep -q ${pkg} || fail "${pkg} not in ${repo}/os/${arch}/${repo}.db.tar.gz"

	local pkgbase=$(getpkgbase "${FTP_BASE}/packages/arch/${arch}/${pkg}")
	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}" ] || fail "svn-packages-copy/${pkgbase}/repos/${repo}-${arch} does not exist"
}

checkRemovedPackage() {
	local repo=$1
	local pkgbase=$2
	local arch=$3

	bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}.db.tar.gz" -O | grep -q ${pkgbase} && fail "${pkgbase} should not be in ${repo}/os/${arch}/${repo}.db.tar.gz"

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}" ] && fail "svn-packages-copy/${pkgbase}/repos/${repo}-${arch} should not exist"
}

checkRemovedAnyPackage() {
	local repo=$1
	local pkgbase=$2
	local arch

	for arch in i686 x86_64; do
		bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}.db.tar.gz" -O | grep -q ${pkgbase} && fail "${pkgbase} should not be in ${repo}/os/${arch}/${repo}.db.tar.gz"
	done

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-any" ] && fail "svn-packages-copy/${pkgbase}/repos/${repo}-any should not exist"
}