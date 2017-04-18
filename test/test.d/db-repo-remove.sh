testRepoRemovePackages() {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			releasePackage extra ${pkgbase} ${arch}
		done
	done

	../db-update

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			../db-repo-remove extra ${arch} ${pkgbase}
		done
	done

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			checkRemovedPackageDB extra ${pkgbase} ${arch}
		done
	done
}

testRepoRemoveMultiplePackages() {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			releasePackage extra ${pkgbase} ${arch}
		done
	done

	../db-update

	for arch in ${arches[@]}; do
		../db-repo-remove extra ${arch} ${pkgs[@]}
	done

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			checkRemovedPackageDB extra ${pkgbase} ${arch}
		done
	done
}

testRepoRemoveAnyPackages() {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase} any
	done

	../db-update

	for pkgbase in ${pkgs[@]}; do
		../db-repo-remove extra any ${pkgbase}
	done

	for pkgbase in ${pkgs[@]}; do
		checkRemovedAnyPackageDB extra ${pkgbase}
	done
}
