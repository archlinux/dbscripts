load ../lib/common

@test "move single packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage testing ${pkgbase}
	done

	db-update

	db-move testing extra pkg-simple-a

	checkRemovedPackage testing pkg-simple-a
	checkPackage extra pkg-simple-a 1-1
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
