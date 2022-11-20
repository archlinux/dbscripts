load ../lib/common

@test "remove single packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-split-a' 'pkg-split-b' 'pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			db-remove extra ${arch} ${pkgbase}
		done
	done

	for pkgbase in ${pkgs[@]}; do
		checkRemovedPackage extra ${pkgbase}
	done
}

@test "remove debug package" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-split-a' 'pkg-split-b' 'pkg-simple-epoch' 'pkg-debuginfo' 'pkg-split-debuginfo')
	local debug_pkgs=('pkg-debuginfo' 'pkg-split-debuginfo')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			db-remove extra ${arch} ${pkgbase}
		done
	done

    checkRemovedPackage extra pkg-debuginfo
	for pkgbase in ${debug_pkgs[@]}; do
		checkRemovedPackage extra-debug ${pkgbase}
	done
}

@test "remove specific debug package" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-split-debuginfo')
	local debug_pkgs=('pkg-split-debuginfo')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

    # We might want to remove the specific debug package
    # without removing the repo packages
	for pkgbase in ${debug_pkgs[@]}; do
		for arch in ${arches[@]}; do
			db-remove extra-debug ${arch} ${pkgbase}-debug
		done
	done

	for pkgbase in ${debug_pkgs[@]}; do
		checkRemovedPackageDB extra-debug ${pkgbase}
	done
}

@test "remove multiple packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-split-a' 'pkg-split-b' 'pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for arch in ${arches[@]}; do
		db-remove extra ${arch} ${pkgs[@]}
	done

	for pkgbase in ${pkgs[@]}; do
		checkRemovedPackage extra ${pkgbase}
	done
}

@test "remove partial split package" {
	local arches=('i686' 'x86_64')
	local arch db

	releasePackage extra pkg-split-a
	db-update

	for arch in ${arches[@]}; do
		db-remove extra "${arch}" pkg-split-a1

		for db in db files; do
			if bsdtar -xf "$FTP_BASE/extra/os/${arch}/extra.${db}" -O | grep pkg-split-a1; then
				return 1
			fi
			bsdtar -xf "$FTP_BASE/extra/os/${arch}/extra.${db}" -O | grep pkg-split-a2
		done
	done
}

@test "remove any packages" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		db-remove extra any ${pkgbase}
	done

	for pkgbase in ${pkgs[@]}; do
		checkRemovedPackage extra ${pkgbase}
	done
}

@test "remove package with insufficient repo permissions fails" {
	local pkgbase='pkg-any-a'

	releasePackage noperm ${pkgbase}

	enablePermission noperm
	db-update
	disablePermissionOverride

	run db-remove noperm any ${pkgbase}
	[ "$status" -ne 0 ]

	checkPackage noperm ${pkgbase} 1-1
}

@test "remove package with author mapping" {
	releasePackage testing pkg-any-a
	db-update

	db-remove testing any pkg-any-a

	checkRemovedPackage testing pkg-any-a
	checkStateRepoAutoredBy "Cake Foobar <foobar@localhost>"
}

@test "remove package with missing author mapping fails" {
	releasePackage testing pkg-any-a
	db-update

	emptyAuthorsFile
	run db-remove testing any pkg-any-a
	[ "$status" -ne 0 ]

	checkPackage testing pkg-any-a 1-1
}
