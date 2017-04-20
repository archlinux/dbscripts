load ../lib/common

@test "testAddSimplePackages" {
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

@test "testAddSingleSimplePackage" {
	releasePackage extra 'pkg-simple-a' 'i686'
	db-update
	checkPackage extra 'pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
}

@test "testAddSingleEpochPackage" {
	releasePackage extra 'pkg-simple-epoch' 'i686'
	db-update
	checkPackage extra 'pkg-simple-epoch-1:1-1-i686.pkg.tar.xz' 'i686'
}

@test "testAddAnyPackages" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase} any
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		checkPackage extra ${pkgbase}-1-1-any.pkg.tar.xz any
	done
}

@test "testAddSplitPackages" {
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
			for pkg in $(getPackageNamesFromPackageBase ${pkgbase}); do
				checkPackage extra ${pkg##*/} ${arch}
			done
		done
	done
}

@test "testUpdateAnyPackage" {
	releasePackage extra pkg-any-a any
	db-update

	updatePackage pkg-any-a any

	releasePackage extra pkg-any-a any
	db-update

	checkPackage extra pkg-any-a-1-2-any.pkg.tar.xz any
}

@test "testUpdateAnyPackageToDifferentRepositoriesAtOnce" {
	releasePackage extra pkg-any-a any

	updatePackage pkg-any-a any

	releasePackage testing pkg-any-a any

	db-update

	checkPackage extra pkg-any-a-1-1-any.pkg.tar.xz any
	checkPackage testing pkg-any-a-1-2-any.pkg.tar.xz any
}

@test "testUpdateSameAnyPackageToSameRepository" {
	releasePackage extra pkg-any-a any
	db-update
	checkPackage extra pkg-any-a-1-1-any.pkg.tar.xz any

	releasePackage extra pkg-any-a any
	run db-update
	[ "$status" -ne 0 ]
}

@test "testUpdateSameAnyPackageToDifferentRepositories" {
	local arch

	releasePackage extra pkg-any-a any
	db-update
	checkPackage extra pkg-any-a-1-1-any.pkg.tar.xz any

	releasePackage testing pkg-any-a any
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB testing pkg-any-a any
}

@test "testAddIncompleteSplitPackage" {
	local arches=('i686' 'x86_64')
	local repo='extra'
	local pkgbase='pkg-split-a'
	local arch

	for arch in ${arches[@]}; do
		releasePackage ${repo} ${pkgbase} ${arch}
	done

	# remove a split package to make db-update fail
	rm "${STAGING}"/extra/${pkgbase}1-*

	run db-update
	[ "$status" -ne 0 ]

	for arch in ${arches[@]}; do
		checkRemovedPackageDB ${repo} ${pkgbase} ${arch}
	done
}

@test "testUnknownRepo" {
	mkdir "${STAGING}/unknown/"
	releasePackage extra 'pkg-simple-a' 'i686'
	releasePackage unknown 'pkg-simple-b' 'i686'
	db-update
	checkPackage extra 'pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
	[ ! -e "${FTP_BASE}/unknown" ]
	rm -rf "${STAGING}/unknown/"
}

@test "testAddUnsignedPackageFails" {
	releasePackage extra 'pkg-simple-a' 'i686'
	rm "${STAGING}"/extra/*.sig
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackage extra pkg-simple-a-1-1-i686.pkg.tar.xz i686
}

@test "testAddInvalidSignedPackageFails" {
	local p
	releasePackage extra 'pkg-simple-a' 'i686'
	for p in "${STAGING}"/extra/*${PKGEXT}; do
		unxz $p
		xz -0 ${p%%.xz}
	done
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackage extra pkg-simple-a-1-1-i686.pkg.tar.xz i686
}

@test "testAddBrokenSignatureFails" {
	local s
	releasePackage extra 'pkg-simple-a' 'i686'
	for s in "${STAGING}"/extra/*.sig; do
		echo 0 > $s
	done
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackage extra pkg-simple-a-1-1-i686.pkg.tar.xz i686
}

@test "testAddPackageWithInconsistentVersionFails" {
	local p
	releasePackage extra 'pkg-simple-a' 'i686'

	for p in "${STAGING}"/extra/*; do
		mv "${p}" "${p/pkg-simple-a-1/pkg-simple-a-2}"
	done

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackage extra 'pkg-simple-a-2-1-i686.pkg.tar.xz' 'i686'
}

@test "testAddPackageWithInconsistentNameFails" {
	local p
	releasePackage extra 'pkg-simple-a' 'i686'

	for p in "${STAGING}"/extra/*; do
		mv "${p}" "${p/pkg-/foo-pkg-}"
	done

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackage extra 'foo-pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
}

@test "testAddPackageWithInconsistentPKGBUILDFails" {
	releasePackage extra 'pkg-simple-a' 'i686'

	updateRepoPKGBUILD 'pkg-simple-a' extra i686

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackage extra 'pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
}

@test "testAddPackageWithInsufficientPermissionsFails" {
	releasePackage core 'pkg-simple-a' 'i686'
	releasePackage extra 'pkg-simple-b' 'i686'

	chmod -xwr ${FTP_BASE}/core/os/i686
	run db-update
	[ "$status" -ne 0 ]
	chmod +xwr ${FTP_BASE}/core/os/i686

	checkRemovedPackage core 'pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
	checkRemovedPackage extra 'pkg-simple-b-1-1-i686.pkg.tar.xz' 'i686'
}

@test "testPackageHasToBeARegularFile" {
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

	run db-update
	[ "$status" -ne 0 ]
	for arch in ${arches[@]}; do
		checkRemovedPackage extra "pkg-simple-a-1-1-${arch}.pkg.tar.xz" $arch
	done
}
