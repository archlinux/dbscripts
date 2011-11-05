set -E

. "$(dirname ${BASH_SOURCE[0]})/../../config"
. "$(dirname ${BASH_SOURCE[0]})/../../db-functions"

oneTimeSetUp() {
	local p
	local d
	local a
	local pkgname
	local pkgarch
	local pkgversion
	local build
	pkgdir="$(mktemp -d /tmp/$(basename $0).XXXXXXXXXX)"
	cp -Lr $(dirname ${BASH_SOURCE[0]})/../packages/* "${pkgdir}"
	msg 'Building packages...'
	for d in "${pkgdir}"/*; do
		pushd $d >/dev/null
		pkgname=($(. PKGBUILD; echo ${pkgname[@]}))
		pkgarch=($(. PKGBUILD; echo ${arch[@]}))
		pkgversion=$(. PKGBUILD; echo $(get_full_version ${epoch:-0} ${pkgver} ${pkgrel}))

		build=true
		for a in ${pkgarch[@]}; do
			for p in ${pkgname[@]}; do
				[ ! -f ${p}-${pkgversion}-${a}${PKGEXT} ] && build=false
			done
		done

		if ! ${build}; then
			if [ "${pkgarch[0]}" == 'any' ]; then
				sudo extra-x86_64-build || die 'extra-x86_64-build failed'
			else
				for a in ${pkgarch[@]}; do
					sudo extra-${a}-build || die "extra-${a}-build failed"
				done
			fi
			for a in ${pkgarch[@]}; do
				for p in ${pkgname[@]}; do
					cp ${p}-${pkgversion}-${a}${PKGEXT} $(dirname ${BASH_SOURCE[0]})/../packages/$(basename ${d})
				done
			done
		fi
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

	[ -f "$(dirname ${BASH_SOURCE[0]})/../../config.local" ] && die "$(dirname ${BASH_SOURCE[0]})/../../config.local exists"
	TMP="$(mktemp -d /dev/shm/$(basename $0).XXXXXXXXXX)"
	#msg "Using ${TMP}"

	PKGREPOS=('core' 'extra' 'testing')
	PKGPOOL='pool/packages'
	mkdir -p "${TMP}/"{ftp,tmp,staging,{package,source}-cleanup,svn-packages-{copy,repo}}

	for r in ${PKGREPOS[@]}; do
		mkdir -p "${TMP}/staging/${r}"
		for a in ${ARCHES[@]} any; do
			mkdir -p "${TMP}/ftp/${r}/os/${a}"
		done
	done
	mkdir -p "${TMP}/ftp/${PKGPOOL}"
	mkdir -p "${TMP}/ftp/${SRCPOOL}"

	msg 'Creating svn repository...'
	svnadmin create "${TMP}/svn-packages-repo"
	svn checkout -q "file://${TMP}/svn-packages-repo" "${TMP}/svn-packages-copy"

	for p in "${pkgdir}"/*; do
		pkg=$(basename $p)
		mkdir -p "${TMP}/svn-packages-copy/${pkg}"/{trunk,repos}
		cp "${p}"/* "${TMP}/svn-packages-copy"/${pkg}/trunk/
		svn add -q "${TMP}/svn-packages-copy"/${pkg}
		svn commit -q -m"initial commit of ${pkg}" "${TMP}/svn-packages-copy"
	done

	cat <<eot > "$(dirname ${BASH_SOURCE[0]})/../../config.local"
	FTP_BASE="${TMP}/ftp"
	SVNREPO="file://${TMP}/svn-packages-repo"
	PKGREPOS=(${PKGREPOS[@]})
	PKGPOOL="${PKGPOOL}"
	CLEANUP_DESTDIR="${TMP}/package-cleanup"
	SOURCE_CLEANUP_DESTDIR="${TMP}/source-cleanup"
	STAGING="${TMP}/staging"
	TMPDIR="${TMP}/tmp"
	CLEANUP_DRYRUN=false
	SOURCE_CLEANUP_DRYRUN=false
	REQUIRE_SIGNATURE=true
eot
	. "$(dirname ${BASH_SOURCE[0]})/../../config"
}

tearDown() {
	rm -rf "${TMP}"
	rm -f "$(dirname ${BASH_SOURCE[0]})/../../config.local"
	echo
}

releasePackage() {
	local repo=$1
	local pkgbase=$2
	local arch=$3

	pushd "${TMP}/svn-packages-copy"/${pkgbase}/trunk/ >/dev/null
	archrelease ${repo}-${arch} >/dev/null 2&>1
	pkgver=$(. PKGBUILD; echo $(get_full_version ${epoch:-0} ${pkgver} ${pkgrel}))
	popd >/dev/null
	cp "${pkgdir}/${pkgbase}"/*-${pkgver}-${arch}${PKGEXT} "${STAGING}"/${repo}/

	if ${REQUIRE_SIGNATURE}; then
		# TODO: really sign the packages with a valid key
		find "${STAGING}"/${repo}/ -type f \
			-name "*-${pkgver}-${arch}${PKGEXT}" \
			-exec touch {}.sig \;
	fi
}

checkAnyPackageDB() {
	local repo=$1
	local pkg=$2
	local arch
	local db

	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}" ] || fail "${PKGPOOL}/${pkg} not found"
	if ${REQUIRE_SIGNATURE}; then
		[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ] || fail "${PKGPOOL}/${pkg}.sig not found"
	fi

	for arch in i686 x86_64; do
		[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ] || fail "${repo}/os/${arch}/${pkg} is not a symlink"
		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}")" == "${FTP_BASE}/${PKGPOOL}/${pkg}" ] \
			|| fail "${repo}/os/${arch}/${pkg} does not link to ${PKGPOOL}/${pkg}"

		if ${REQUIRE_SIGNATURE}; then
			[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig" ] || fail "${repo}/os/${arch}/${pkg}.sig is not a symlink"
			[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig")" == "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ] \
				|| fail "${repo}/os/${arch}/${pkg}.sig does not link to ${PKGPOOL}/${pkg}.sig"
		fi
	done
	[ -r "${STAGING}"/${repo}/${pkg} ] && fail "${repo}/${pkg} found in staging dir"
	[ -r "${STAGING}"/${repo}/${pkg}.sig ] && fail "${repo}/${pkg}.sig found in staging dir"

	for db in ${DBEXT} ${FILESEXT}; do
		( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" ] \
			&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" -O | grep -q ${pkg}) \
			|| fail "${pkg} not in ${repo}/os/${arch}/${repo}${db%.tar.*}"
	done

	[ -r "${FTP_BASE}/${repo}/os/any/${pkg}" ] && fail "${repo}/os/any/${pkg} should not exist"
	[ -r "${FTP_BASE}/${repo}/os/any/${pkg}.sig" ] && fail "${repo}/os/any/${pkg}.sig should not exist"
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

	if ${REQUIRE_SIGNATURE}; then
		[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ] || fail "${PKGPOOL}/${pkg}.sig not found"
		[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig" ] || fail "${repo}/os/${arch}/${pkg}.sig is not a symlink"
		[ -r "${STAGING}"/${repo}/${pkg}.sig ] && fail "${repo}/${pkg}.sig found in staging dir"

		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig")" == "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ] \
			|| fail "${repo}/os/${arch}/${pkg}.sig does not link to ${PKGPOOL}/${pkg}.sig"
	fi

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
