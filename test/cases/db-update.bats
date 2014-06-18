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
		checkPackage extra ${pkgbase}
	done
}

@test "add single simple package" {
	releasePackage extra 'pkg-single-arch'
	db-update
	checkPackage extra 'pkg-single-arch'
}

@test "add single epoch package" {
	releasePackage extra 'pkg-single-epoch'
	db-update
	checkPackage extra 'pkg-single-epoch'
}

@test "add any packages" {
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
		checkPackage extra ${pkgbase}
	done
}

@test "update any package" {
	releasePackage extra pkg-any-a
	db-update

	updatePackage pkg-any-a

	releasePackage extra pkg-any-a
	db-update

	checkPackage extra pkg-any-a
}

@test "update any package to different repositories at once" {
	releasePackage extra pkg-any-a

	updatePackage pkg-any-a

	releasePackage testing pkg-any-a

	db-update

	checkPackage extra pkg-any-a
	checkPackage testing pkg-any-a
}

@test "update same any package to same repository fails" {
	releasePackage extra pkg-any-a
	db-update
	checkPackage extra pkg-any-a

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
	checkPackage extra pkg-any-a

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
	checkPackage extra 'pkg-any-a'
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
	checkRemovedPackage extra 'pkg-any-a'
}

@test "add package with inconsistent pkgbuild fails" {
	releasePackage extra 'pkg-any-a'

	updateRepoPKGBUILD 'pkg-any-a' extra any

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackageDB extra 'pkg-any-a'
}

@test "add package with insufficient permissions fails" {
	releasePackage core 'pkg-any-a'
	releasePackage extra 'pkg-any-b'

	chmod -xwr ${FTP_BASE}/core/os/i686
	run db-update
	[ "$status" -ne 0 ]
	chmod +xwr ${FTP_BASE}/core/os/i686

	checkRemovedPackageDB core 'pkg-any-a'
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
