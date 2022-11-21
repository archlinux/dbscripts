load ../lib/common

@test "add simple packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		checkPackage extra ${pkgbase} 1-1
	done
}

@test "add single simple package" {
	releasePackage extra 'pkg-single-arch'
	db-update
	checkPackage extra 'pkg-single-arch' 1-1
}

@test "add debug package" {
	releasePackage extra 'pkg-debuginfo'
	db-update
	checkPackage extra 'pkg-debuginfo' 1-1
	checkPackage extra-debug 'pkg-debuginfo' 1-1
}

@test "add single epoch package" {
	releasePackage extra 'pkg-single-epoch'
	db-update
	checkPackage extra 'pkg-single-epoch' 1:1-1
}

@test "add any packages" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		checkPackage extra ${pkgbase} 1-1
	done
}

@test "add split packages" {
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
		checkPackage extra ${pkgbase} 1-1
	done
}

@test "update any package" {
	releasePackage extra pkg-any-a
	db-update

	updatePackage pkg-any-a

	releasePackage extra pkg-any-a
	db-update

	checkPackage extra pkg-any-a 1-2
}

@test "update any package to different repositories at once" {
	releasePackage extra pkg-any-a

	updatePackage pkg-any-a

	releasePackage testing pkg-any-a

	db-update

	checkPackage extra pkg-any-a 1-1
	checkPackage testing pkg-any-a 1-2
}

@test "archive package when releasing" {
	releasePackage extra pkg-any-a
	db-update
	[[ -f ${ARCHIVE_BASE}/packages/p/pkg-any-a/pkg-any-a-1-1-any${PKGEXT} ]]
	[[ -f ${ARCHIVE_BASE}/packages/p/pkg-any-a/pkg-any-a-1-1-any${PKGEXT}.sig ]]
}

@test "update any package to stable repo without updating testing package fails" {
	releasePackage extra pkg-any-a
	db-update
	updatePackage pkg-any-a
	releasePackage testing pkg-any-a
	db-update
	updatePackage pkg-any-a
	releasePackage extra pkg-any-a

	run db-update
	[ "$status" -ne 0 ]
}

@test "update any package to stable repo without updating staging package fails" {
	releasePackage extra pkg-any-a
	db-update
	updatePackage pkg-any-a
	releasePackage staging pkg-any-a
	db-update
	updatePackage pkg-any-a
	releasePackage extra pkg-any-a

	run db-update
	echo "$output"
	[ "$status" -ne 0 ]
}

@test "update same any package to same repository fails" {
	releasePackage extra pkg-any-a
	db-update
	checkPackage extra pkg-any-a 1-1

	PKGEXT=.pkg.tar.gz releasePackage extra pkg-any-a
	run db-update
	[ "$status" -ne 0 ]
}

@test "update duplicate package fails" {
	PKGEXT=.pkg.tar.xz releasePackage extra pkg-any-a
	PKGEXT=.pkg.tar.gz releasePackage extra pkg-any-a
	run db-update
	[ "$status" -ne 0 ]
}

@test "update same any package to different repositories fails" {
	local arch

	releasePackage extra pkg-any-a
	db-update
	checkPackage extra pkg-any-a 1-1

	releasePackage testing pkg-any-a
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB testing pkg-any-a
}

@test "add incomplete split package fails" {
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

@test "add package to unknown repo fails" {
	mkdir "${STAGING}/unknown/"
	releasePackage extra 'pkg-any-a'
	releasePackage unknown 'pkg-any-b'
	db-update
	checkPackage extra 'pkg-any-a' 1-1
	[ ! -e "${FTP_BASE}/unknown" ]
	rm -rf "${STAGING}/unknown/"
}

@test "add unsigned package fails" {
	releasePackage extra 'pkg-any-a'
	rm "${STAGING}"/extra/*.sig
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB extra pkg-any-a
}

@test "add invalid signed package fails" {
	local p
	releasePackage extra 'pkg-any-a'
	for p in "${STAGING}"/extra/*${PKGEXT}; do
		printf '%s\n' "Not a real package" | gpg -v --detach-sign --no-armor --use-agent - > "${p}.sig"
	done
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB extra pkg-any-a
}

@test "add broken signature fails" {
	local s
	releasePackage extra 'pkg-any-a'
	for s in "${STAGING}"/extra/*.sig; do
		echo 0 > $s
	done
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB extra pkg-any-a
}

@test "add package with inconsistent version fails" {
	local p
	releasePackage extra 'pkg-any-a'

	for p in "${STAGING}"/extra/*; do
		mv "${p}" "${p/pkg-any-a-1/pkg-any-a-2}"
	done

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackageDB extra 'pkg-any-a'
}

@test "add package with inconsistent name fails" {
	local p
	releasePackage extra 'pkg-any-a'

	for p in "${STAGING}"/extra/*; do
		mv "${p}" "${p/pkg-/foo-pkg-}"
	done

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackageDB extra 'pkg-any-a'
}

@test "add package with inconsistent pkgbuild in branch succeeds" {
	releasePackage extra 'pkg-any-a'

	updateRepoPKGBUILD 'pkg-any-a' extra any

	db-update
	checkPackage extra 'pkg-any-a' 1-1
}

@test "add package with inconsistent pkgbuild in tag fails" {
	releasePackage extra 'pkg-any-a'

	retagModifiedPKGBUILD 'pkg-any-a'

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackageDB extra 'pkg-any-a'
}

@test "add package with insufficient directory permissions fails" {
	releasePackage core 'pkg-any-a'
	releasePackage extra 'pkg-any-b'

	chmod -xwr ${FTP_BASE}/core/os/i686
	run db-update
	[ "$status" -ne 0 ]
	chmod +xwr ${FTP_BASE}/core/os/i686

	checkRemovedPackageDB core 'pkg-any-a'
	checkRemovedPackageDB extra 'pkg-any-b'
}

@test "add package with insufficient repo permissions fails" {
	releasePackage noperm 'pkg-any-a'
	releasePackage extra 'pkg-any-b'

	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB noperm 'pkg-any-a'
	checkRemovedPackageDB extra 'pkg-any-b'
}

@test "package has to be aregular file" {
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

@test "Wrong BUILDDIR" {
	local target=$(mktemp -d)
	BUILDDIR=$target releasePackage extra 'pkg-single-arch'
	run db-update
	(( $status == 1 ))
	[[ $output == *'was not built in a chroot'* ]]
}

@test "add split debug packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-split-debuginfo')
	local pkg
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		checkPackage extra-debug ${pkgbase} 1-1
	done
}

@test "add package with author mapping" {
	releasePackage extra pkg-any-a

	db-update

	checkPackage extra pkg-any-a 1-1
	checkStateRepoAutoredBy "Cake Foobar <foobar@localhost>"
}

@test "add package with missing author mapping fails" {
	releasePackage extra pkg-any-a

	emptyAuthorsFile
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackage extra pkg-any-a
}
