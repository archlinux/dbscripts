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
