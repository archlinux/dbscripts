testAddSimplePackages() {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			releasePackage extra ${pkgbase} ${arch}
		done
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			checkPackage extra ${pkgbase}-1-1-${arch}.pkg.tar.xz ${arch}
		done
	done
}

testAddSingleSimplePackage() {
	releasePackage extra 'pkg-simple-a' 'i686'
	db-update
	checkPackage extra 'pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
}

testAddSingleEpochPackage() {
	releasePackage extra 'pkg-simple-epoch' 'i686'
	db-update
	checkPackage extra 'pkg-simple-epoch-1:1-1-i686.pkg.tar.xz' 'i686'
}

testAddAnyPackages() {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase} any
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		checkAnyPackage extra ${pkgbase}-1-1-any.pkg.tar.xz
	done
}

testAddSplitPackages() {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-split-a' 'pkg-split-b')
	local pkg
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			releasePackage extra ${pkgbase} ${arch}
		done
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			for pkg in "${pkgdir}/${pkgbase}"/*-${arch}${PKGEXT}; do
				checkPackage extra ${pkg##*/} ${arch}
			done
		done
	done
}

testUpdateAnyPackage() {
	releasePackage extra pkg-any-a any
	db-update

	updatePackage pkg-any-a

	releasePackage extra pkg-any-a any
	db-update

	checkAnyPackage extra pkg-any-a-1-2-any.pkg.tar.xz any
}

testUpdateAnyPackageToDifferentRepositoriesAtOnce() {
	releasePackage extra pkg-any-a any

	updatePackage pkg-any-a

	releasePackage testing pkg-any-a any

	db-update

	checkAnyPackage extra pkg-any-a-1-1-any.pkg.tar.xz any
	checkAnyPackage testing pkg-any-a-1-2-any.pkg.tar.xz any
}

testUpdateSameAnyPackageToSameRepository() {
	releasePackage extra pkg-any-a any
	db-update
	checkAnyPackage extra pkg-any-a-1-1-any.pkg.tar.xz any

	releasePackage extra pkg-any-a any
	db-update >/dev/null 2>&1 && (fail 'Adding an existing package to the same repository should fail'; return 1)
}

testUpdateSameAnyPackageToDifferentRepositories() {
	releasePackage extra pkg-any-a any
	db-update
	checkAnyPackage extra pkg-any-a-1-1-any.pkg.tar.xz any

	releasePackage testing pkg-any-a any
	db-update >/dev/null 2>&1 && (fail 'Adding an existing package to another repository should fail'; return 1)

	local arch
	for arch in i686 x86_64; do
		( [ -r "${FTP_BASE}/testing/os/${arch}/testing${DBEXT%.tar.*}" ] \
			&& bsdtar -xf "${FTP_BASE}/testing/os/${arch}/testing${DBEXT%.tar.*}" -O | grep -q ${pkgbase}) \
			&& fail "${pkgbase} should not be in testing/os/${arch}/testing${DBEXT%.tar.*}"
	done
}

testAddIncompleteSplitPackage() {
	local arches=('i686' 'x86_64')
	local repo='extra'
	local pkgbase='pkg-split-a'
	local arch

	for arch in ${arches[@]}; do
		releasePackage ${repo} ${pkgbase} ${arch}
	done

	# remove a split package to make db-update fail
	rm "${STAGING}"/extra/${pkgbase}1-*

	db-update >/dev/null 2>&1 && fail "db-update should fail when a split package is missing!"

	for arch in ${arches[@]}; do
		( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" ] \
		&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" -O | grep -q ${pkgbase}) \
		&& fail "${pkgbase} should not be in ${repo}/os/${arch}/${repo}${DBEXT%.tar.*}"
	done
}

testUnknownRepo() {
	mkdir "${STAGING}/unknown/"
	releasePackage extra 'pkg-simple-a' 'i686'
	releasePackage unknown 'pkg-simple-b' 'i686'
	db-update
	checkPackage extra 'pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
	[ -e "${FTP_BASE}/unknown" ] && fail "db-update pushed a package into an unknown repository"
	rm -rf "${STAGING}/unknown/"
}

testAddUnsignedPackageFails() {
	releasePackage extra 'pkg-simple-a' 'i686'
	rm "${STAGING}"/extra/*.sig
	db-update >/dev/null 2>&1 && fail "db-update should fail when a signature is missing!"

	checkRemovedPackage extra pkg-simple-a-1-1-i686.pkg.tar.xz i686
}

testAddInvalidSignedPackageFails() {
	local p
	releasePackage extra 'pkg-simple-a' 'i686'
	for p in "${STAGING}"/extra/*${PKGEXT}; do
		unxz $p
		xz -0 ${p%%.xz}
	done
	db-update >/dev/null 2>&1 && fail "db-update should fail when a signature is invalid!"

	checkRemovedPackage extra pkg-simple-a-1-1-i686.pkg.tar.xz i686
}

testAddBrokenSignatureFails() {
	local s
	releasePackage extra 'pkg-simple-a' 'i686'
	for s in "${STAGING}"/extra/*.sig; do
		echo 0 > $s
	done
	db-update >/dev/null 2>&1 && fail "db-update should fail when a signature is broken!"

	checkRemovedPackage extra pkg-simple-a-1-1-i686.pkg.tar.xz i686
}

testAddPackageWithInconsistentVersionFails() {
	local p
	releasePackage extra 'pkg-simple-a' 'i686'

	for p in "${STAGING}"/extra/*; do
		mv "${p}" "${p/pkg-simple-a-1/pkg-simple-a-2}"
	done

	db-update >/dev/null 2>&1 && fail "db-update should fail when a package is not consistent!"
	checkRemovedPackage extra 'pkg-simple-a-2-1-i686.pkg.tar.xz' 'i686'
}

testAddPackageWithInconsistentNameFails() {
	local p
	releasePackage extra 'pkg-simple-a' 'i686'

	for p in "${STAGING}"/extra/*; do
		mv "${p}" "${p/pkg-/foo-pkg-}"
	done

	db-update >/dev/null 2>&1 && fail "db-update should fail when a package is not consistent!"
	checkRemovedPackage extra 'foo-pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
}

testAddPackageWithInconsistentPKGBUILDFails() {
	releasePackage extra 'pkg-simple-a' 'i686'

	updateRepoPKGBUILD 'pkg-simple-a' extra i686

	db-update >/dev/null 2>&1 && fail "db-update should fail when a package is not consistent!"
	checkRemovedPackage extra 'pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
}

testAddPackageWithInsufficientPermissionsFails()
{
	releasePackage core 'pkg-simple-a' 'i686'
	releasePackage extra 'pkg-simple-b' 'i686'

	chmod -xwr ${FTP_BASE}/core/os/i686
	db-update >/dev/null 2>&1 && fail "db-update should fail when permissions are insufficient!"
	chmod +xwr ${FTP_BASE}/core/os/i686

	checkRemovedPackage core 'pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
	checkRemovedPackage extra 'pkg-simple-b-1-1-i686.pkg.tar.xz' 'i686'
}

testPackageHasToBeARegularFile()
{
	local p
	local target=$(mktemp -d)
	local arches=('i686' 'x86_64')

	for arch in ${arches[@]}; do
		releasePackage extra 'pkg-simple-a' $arch
	done

	for p in "${STAGING}"/extra/*i686*; do
		mv "${p}" "${target}"
		ln -s "${target}/${p##*/}" "${p}"
	done

	db-update >/dev/null 2>&1 && fail "db-update should fail when a package is a symlink!"
	for arch in ${arches[@]}; do
		checkRemovedPackage extra "pkg-simple-a-1-1-${arch}.pkg.tar.xz" $arch
	done
}
