load ../lib/common

@test "testSourceballs" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			releasePackage extra ${pkgbase} ${arch}
		done
	done
	db-update

	sourceballs
	for pkgbase in ${pkgs[@]}; do
		[ -r ${FTP_BASE}/${SRCPOOL}/${pkgbase}-*${SRCEXT} ]
	done
}

@test "testAnySourceballs" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase} any
	done
	db-update

	sourceballs
	for pkgbase in ${pkgs[@]}; do
		[ -r ${FTP_BASE}/${SRCPOOL}/${pkgbase}-*${SRCEXT} ]
	done
}

@test "testSplitSourceballs" {
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

	sourceballs
	for pkgbase in ${pkgs[@]}; do
		[ -r ${FTP_BASE}/${SRCPOOL}/${pkgbase}-*${SRCEXT} ]
	done
}

@test "testSourceballsCleanup" {
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
	sourceballs

	for arch in ${arches[@]}; do
		db-remove extra ${arch} pkg-simple-a
	done

	sourceballs
	[ ! -r ${FTP_BASE}/${SRCPOOL}/pkg-simple-a-*${SRCEXT} ]
	[ -r ${FTP_BASE}/${SRCPOOL}/pkg-simple-b-*${SRCEXT} ]
}
