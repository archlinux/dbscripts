testRepoAddSimplePackages() {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			cp "${pkgdir}/${pkgbase}/${pkgbase}-1-1-${arch}.pkg.tar.xz" "${FTP_BASE}/${PKGPOOL}/"
			touch "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-${arch}.pkg.tar.xz.sig"
			ln -s "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-${arch}.pkg.tar.xz" "${FTP_BASE}/extra/os/${arch}/"
			ln -s "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-${arch}.pkg.tar.xz.sig" "${FTP_BASE}/extra/os/${arch}/"
			../db-repo-add extra ${arch} ${pkgbase}-1-1-${arch}.pkg.tar.xz
		done
	done

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			checkPackageDB extra ${pkgbase}-1-1-${arch}.pkg.tar.xz ${arch}
		done
	done
}

testRepoAddMultiplePackages() {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for arch in ${arches[@]}; do
		add_pkgs=()
		for pkgbase in ${pkgs[@]}; do
			cp "${pkgdir}/${pkgbase}/${pkgbase}-1-1-${arch}.pkg.tar.xz" "${FTP_BASE}/${PKGPOOL}/"
			touch "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-${arch}.pkg.tar.xz.sig"
			ln -s "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-${arch}.pkg.tar.xz" "${FTP_BASE}/extra/os/${arch}/"
			ln -s "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-${arch}.pkg.tar.xz.sig" "${FTP_BASE}/extra/os/${arch}/"
			add_pkgs[${#add_pkgs[*]}]=${pkgbase}-1-1-${arch}.pkg.tar.xz
		done
		../db-repo-add extra ${arch} ${add_pkgs[@]}
	done

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			checkPackageDB extra ${pkgbase}-1-1-${arch}.pkg.tar.xz ${arch}
		done
	done
}

testRepoAddAnyPackages() {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		cp "${pkgdir}/${pkgbase}/${pkgbase}-1-1-any.pkg.tar.xz" "${FTP_BASE}/${PKGPOOL}/"
		touch "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-any.pkg.tar.xz.sig"
		for arch in ${arches[@]}; do
			ln -s "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-any.pkg.tar.xz" "${FTP_BASE}/extra/os/${arch}/"
			ln -s "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-any.pkg.tar.xz.sig" "${FTP_BASE}/extra/os/${arch}/"
		done
		../db-repo-add extra any ${pkgbase}-1-1-any.pkg.tar.xz
	done

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			checkPackageDB extra ${pkgbase}-1-1-any.pkg.tar.xz ${arch}
		done
	done
}
