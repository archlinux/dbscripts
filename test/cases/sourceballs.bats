load ../lib/common

__checkSourcePackage() {
	local pkgbase=$1
	__isGlobfile "${FTP_BASE}/${SRCPOOL}/${pkgbase}"-*"${SRCEXT}"
}

__checkRemovedSourcePackage() {
	local pkgbase=$1
	! __isGlobfile "${FTP_BASE}/${SRCPOOL}/${pkgbase}"-*"${SRCEXT}"
}

@test "create simple package sourceballs" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done
	db-update

	sourceballs
	for pkgbase in ${pkgs[@]}; do
		__checkSourcePackage ${pkgbase}
	done
}

@test "create any package sourceballs" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done
	db-update

	sourceballs
	for pkgbase in ${pkgs[@]}; do
		__checkSourcePackage ${pkgbase}
	done
}

@test "create split package sourceballs" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-split-a' 'pkg-split-b')
	local pkg
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	sourceballs
	for pkgbase in ${pkgs[@]}; do
		__checkSourcePackage ${pkgbase}
	done
}

@test "cleanup sourceballs" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done
	db-update
	sourceballs

	for arch in ${arches[@]}; do
		db-remove extra ${arch} pkg-simple-a
	done

	sourceballs
	__checkRemovedSourcePackage pkg-simple-a
	__checkSourcePackage pkg-simple-b
}
