load ../lib/common

@test "testAddSimplePackages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		checkPackage extra ${pkgbase}
	done
}

@test "testAddSingleSimplePackage" {
	releasePackage extra 'pkg-single-arch'
	db-update
	checkPackage extra 'pkg-single-arch'
}

@test "testAddSingleEpochPackage" {
	releasePackage extra 'pkg-single-epoch'
	db-update
	checkPackage extra 'pkg-single-epoch'
}

@test "testAddAnyPackages" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		checkPackage extra ${pkgbase}
	done
}

@test "testAddSplitPackages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-split-a' 'pkg-split-b')
	local pkg
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		checkPackage extra ${pkgbase}
	done
}

@test "testUpdateAnyPackage" {
	releasePackage extra pkg-any-a
	db-update

	updatePackage pkg-any-a

	releasePackage extra pkg-any-a
	db-update

	checkPackage extra pkg-any-a
}

@test "testUpdateAnyPackageToDifferentRepositoriesAtOnce" {
	releasePackage extra pkg-any-a

	updatePackage pkg-any-a

	releasePackage testing pkg-any-a

	db-update

	checkPackage extra pkg-any-a
	checkPackage testing pkg-any-a
}

@test "testUpdateSameAnyPackageToSameRepository" {
	releasePackage extra pkg-any-a
	db-update
	checkPackage extra pkg-any-a

	releasePackage extra pkg-any-a
	run db-update
	[ "$status" -ne 0 ]
}

@test "testUpdateSameAnyPackageToDifferentRepositories" {
	local arch

	releasePackage extra pkg-any-a
	db-update
	checkPackage extra pkg-any-a

	releasePackage testing pkg-any-a
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB testing pkg-any-a
}

@test "testAddIncompleteSplitPackage" {
	local arches=('i686' 'x86_64')
	local repo='extra'
	local pkgbase='pkg-split-a'
	local arch

	releasePackage ${repo} ${pkgbase}

	# remove a split package to make db-update fail
	rm "${STAGING}"/extra/${pkgbase}1-*

	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB ${repo} ${pkgbase}
}

@test "testUnknownRepo" {
	mkdir "${STAGING}/unknown/"
	releasePackage extra 'pkg-any-a'
	releasePackage unknown 'pkg-any-b'
	db-update
	checkPackage extra 'pkg-any-a'
	[ ! -e "${FTP_BASE}/unknown" ]
	rm -rf "${STAGING}/unknown/"
}

@test "testAddUnsignedPackageFails" {
	releasePackage extra 'pkg-any-a'
	rm "${STAGING}"/extra/*.sig
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB extra pkg-any-a
}

@test "testAddInvalidSignedPackageFails" {
	local p
	releasePackage extra 'pkg-any-a'
	for p in "${STAGING}"/extra/*${PKGEXT}; do
		unxz $p
		xz -0 ${p%%.xz}
	done
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB extra pkg-any-a
}

@test "testAddBrokenSignatureFails" {
	local s
	releasePackage extra 'pkg-any-a'
	for s in "${STAGING}"/extra/*.sig; do
		echo 0 > $s
	done
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB extra pkg-any-a
}

@test "testAddPackageWithInconsistentVersionFails" {
	local p
	releasePackage extra 'pkg-any-a'

	for p in "${STAGING}"/extra/*; do
		mv "${p}" "${p/pkg-any-a-1/pkg-any-a-2}"
	done

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackageDB extra 'pkg-any-a'
}

@test "testAddPackageWithInconsistentNameFails" {
	local p
	releasePackage extra 'pkg-any-a'

	for p in "${STAGING}"/extra/*; do
		mv "${p}" "${p/pkg-/foo-pkg-}"
	done

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackage extra 'pkg-any-a'
}

@test "testAddPackageWithInconsistentPKGBUILDFails" {
	releasePackage extra 'pkg-any-a'

	updateRepoPKGBUILD 'pkg-any-a' extra any

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackageDB extra 'pkg-any-a'
}

@test "testAddPackageWithInsufficientPermissionsFails" {
	releasePackage core 'pkg-any-a'
	releasePackage extra 'pkg-any-b'

	chmod -xwr ${FTP_BASE}/core/os/i686
	run db-update
	[ "$status" -ne 0 ]
	chmod +xwr ${FTP_BASE}/core/os/i686

	checkRemovedPackageDB core 'pkg-any-a'
	checkRemovedPackageDB extra 'pkg-any-b'
}

@test "testPackageHasToBeARegularFile" {
	local p
	local target=$(mktemp -d)
	local arches=('i686' 'x86_64')

	releasePackage extra 'pkg-simple-a'

	for p in "${STAGING}"/extra/*i686*; do
		mv "${p}" "${target}"
		ln -s "${target}/${p##*/}" "${p}"
	done

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackageDB extra "pkg-simple-a"
}
