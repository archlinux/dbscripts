load ../lib/common

@test "move single packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		echo "releasing to testing: $pkgbase"
		releasePackage testing ${pkgbase}
	done

    echo "db-updating..."
	db-update

    echo "db-move testing -> extra pkg-simple-a"
	db-move testing extra pkg-simple-a

	echo checkRemovedPackage testing pkg-simple-a
	checkRemovedPackage testing pkg-simple-a
	echo checkPackage extra pkg-simple-a 1-1
	checkPackage extra pkg-simple-a 1-1
	echo checkPackage testing pkg-simple-b 1-1
	checkPackage testing pkg-simple-b 1-1
}

@test "move debug package" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-debuginfo' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		echo "releasing to testing: $pkgbase"
		releasePackage testing ${pkgbase}
	done

	echo "db-updating..."
	db-update

	echo "db-move testing -> extra pkg-debuginfo"
	db-move testing extra pkg-debuginfo

	echo checkRemovedPackage testing pkg-debuginfo
	checkRemovedPackage testing pkg-debuginfo

	echo checkRemovedPackage testing-debug pkg-debuginfo-debug
	checkRemovedPackage testing-debug pkg-debuginfo-debug

	echo checkPackage extra pkg-debuginfo 1-1
	checkPackage extra pkg-debuginfo 1-1

	echo checkPackage extra-debug pkg-debuginfo 1-1
	checkPackage extra-debug pkg-debuginfo 1-1

	echo checkPackage testing pkg-simple-b 1-1
	checkPackage testing pkg-simple-b 1-1
}

@test "move multiple packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage testing ${pkgbase}
	done

	db-update

	db-move testing extra pkg-simple-a pkg-simple-b

	for pkgbase in ${pkgs[@]}; do
		checkRemovedPackage testing ${pkgbase}
		checkPackage extra ${pkgbase} 1-1
	done
}

@test "move package from staging to extra while a testing package exists fails" {
	releasePackage extra pkg-any-a
	db-update
	updatePackage pkg-any-a
	releasePackage testing pkg-any-a
	db-update
	updatePackage pkg-any-a
	releasePackage staging pkg-any-a
	db-update

	run db-move staging extra pkg-any-a
	[ "$status" -ne 0 ]
}

@test "move single-arch packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-single-arch' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage testing ${pkgbase}
	done

	db-update

	db-move testing extra pkg-single-arch

	checkRemovedPackage testing pkg-single-arch
	checkPackage extra pkg-single-arch 1-1
	checkPackage testing pkg-simple-b 1-1
}

@test "move epoch packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage testing ${pkgbase}
	done

	db-update

	db-move testing extra pkg-simple-epoch

	checkRemovedPackage testing pkg-simple-epoch
	checkPackage extra pkg-simple-epoch 1:1-1
}

@test "move any packages" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in ${pkgs[@]}; do
		releasePackage testing ${pkgbase}
	done

	db-update
	db-move testing extra pkg-any-a

	checkPackage extra pkg-any-a 1-1
	checkRemovedPackage testing pkg-any-a
	checkPackage testing pkg-any-b 1-1
}

@test "move split packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-split-a' 'pkg-split-b')
	local pkg
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage testing ${pkgbase}
	done

	db-update
	db-move testing extra pkg-split-a

	checkPackage extra pkg-split-a 1-1
	checkPackage testing pkg-split-b 1-1
}

@test "move not valid repo" {
	releasePackage extra pkg-any-a
	db-update

	run db-move extra community pkg-any-a
	[ "$status" -ne 0 ]
	[[ $output == *'community is not a valid'* ]]

	run db-move notconfigured community pkg-any-a
	[ "$status" -ne 0 ]
	[[ $output == *'notconfigured is not a valid'* ]]
}

@test "move split packages with debug" {
	local arches=('x86_64')
	local pkgs=('pkg-split-debuginfo')
	local pkg
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage testing ${pkgbase}
	done

	db-update
	db-move testing extra pkg-split-debuginfo

	checkPackage extra pkg-split-debuginfo 1-1
	checkPackage extra-debug pkg-split-debuginfo 1-1
}

@test "move package with insufficient target repo permissions fails" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage testing ${pkgbase}
	done

	db-update

	run db-move testing noperm pkg-simple-a pkg-simple-b
	[ "$status" -ne 0 ]

	for pkgbase in ${pkgs[@]}; do
		checkRemovedPackage noperm ${pkgbase}
		checkPackage testing ${pkgbase} 1-1
	done
}

@test "move package with insufficient source repo permissions fails" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage noperm ${pkgbase}
	done

	enablePermission noperm
	db-update
	disablePermissionOverride

	run db-move noperm testing pkg-simple-a pkg-simple-b
	[ "$status" -ne 0 ]

	for pkgbase in ${pkgs[@]}; do
		checkRemovedPackage testing ${pkgbase}
		checkPackage noperm ${pkgbase} 1-1
	done
}

@test "move package with author mapping" {
	releasePackage testing pkg-any-a
	db-update

	db-move testing extra pkg-any-a

	checkPackage extra pkg-any-a 1-1
	checkRemovedPackage testing pkg-any-a
	checkStateRepoAutoredBy "Cake Foobar <foobar@localhost>"
}

@test "move package with missing author mapping fails" {
	releasePackage testing pkg-any-a
	db-update

	emptyAuthorsFile
	run db-move testing extra pkg-any-a
	[ "$status" -ne 0 ]

	checkPackage testing pkg-any-a 1-1
	checkRemovedPackage extra pkg-any-a
}
