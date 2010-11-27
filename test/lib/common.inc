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
	pkgdir="$(mktemp -d /dev/shm/$(basename $0).XXXXXXXXXX)"
	cp -Lr $(dirname ${BASH_SOURCE[0]})/../packages/* "${pkgdir}"
	msg 'Building packages...'
	for d in "${pkgdir}"/*; do
		pushd $d >/dev/null
		pkgname=($(. PKGBUILD; echo ${pkgname[@]}))
		pkgarch=($(. PKGBUILD; echo ${arch[@]}))
		pkgversion=$(. PKGBUILD; echo ${pkgver}-${pkgrel})

		build=true
		for a in ${pkgarch[@]}; do
			for p in ${pkgname[@]}; do
				[ ! -f ${p}-${pkgversion}-${a}${PKGEXT} ] && build=false
			done
		done

		if ! ${build}; then
			if [ "${pkgarch[0]}" == 'any' ]; then
				extra-x86_64-build || die 'extra-x86_64-build failed'
			else
				for a in ${pkgarch[@]}; do
					extra-${a}-build || die "extra-${a}-build failed"
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
	pkgver=$(. PKGBUILD; echo "${pkgver}-${pkgrel}")
	popd >/dev/null
	cp "${pkgdir}/${pkgbase}"/*-${pkgver}-${arch}.pkg.tar.* "${STAGING}"/${repo}/
}

checkAnyPackage() {
	local repo=$1
	local pkg=$2
	local arch

	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}" ] || fail "${PKGPOOL}/${pkg} not found"

	for arch in i686 x86_64; do
		[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ] || fail "${repo}/os/${arch}/${pkg} not a symlink"
		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}")" == "${FTP_BASE}/${PKGPOOL}/${pkg}" ] \
			|| fail "${repo}/os/${arch}/${pkg} does not link to ${PKGPOOL}/${pkg}"
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

	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}" ] || fail "${PKGPOOL}/${pkg} not found"
	[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ] || fail "${repo}/os/${arch}/${pkg} not a symlink"
	[ -r "${STAGING}"/${repo}/${pkg} ] && fail "${repo}/${pkg} found in staging dir"

	[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}")" == "${FTP_BASE}/${PKGPOOL}/${pkg}" ] \
		|| fail "${repo}/os/${arch}/${pkg} does not link to ${PKGPOOL}/${pkg}"

	( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" ] \
		&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" -O | grep -q ${pkg}) \
		|| fail "${pkg} not in ${repo}/os/${arch}/${repo}${DBEXT%.tar.*}"

	local pkgbase=$(getpkgbase "${FTP_BASE}/${PKGPOOL}/${pkg}")
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
