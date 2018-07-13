load ../lib/common

__movePackageToRepo() {
	local repo=$1
	local pkgbase=$2
	local arch=$3
	local tarch
	local tarches

	if [[ $arch == any ]]; then
		tarches=(${ARCHES[@]})
	else
		tarches=(${arch})
	fi

	# FIXME: pkgbase might not be part of the package filename
	mv -v "${STAGING}"/${repo}/${pkgbase}-*-*-${arch}${PKGEXT}{,.sig} "${FTP_BASE}/${PKGPOOL}/"
	for tarch in ${tarches[@]}; do
		ln -sv ${FTP_BASE}/${PKGPOOL}/${pkgbase}-*-*-${arch}${PKGEXT} "${FTP_BASE}/${repo}/os/${tarch}/"
		ln -sv ${FTP_BASE}/${PKGPOOL}/${pkgbase}-*-*-${arch}${PKGEXT}.sig "${FTP_BASE}/${repo}/os/${tarch}/"
	done
}

@test "add single packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
		for arch in ${arches[@]}; do
			__movePackageToRepo extra ${pkgbase} ${arch}
			db-repo-add extra ${arch} ${pkgbase}-1-1-${arch}${PKGEXT}
		done
	done

	for pkgbase in ${pkgs[@]}; do
		checkPackageDB extra ${pkgbase} 1-1
	done
}

@test "add multiple packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	for arch in ${arches[@]}; do
		add_pkgs=()
		for pkgbase in ${pkgs[@]}; do
			__movePackageToRepo extra ${pkgbase} ${arch}
			add_pkgs+=("${pkgbase}-1-1-${arch}${PKGEXT}")
		done
		db-repo-add extra ${arch} ${add_pkgs[@]}
	done

	for pkgbase in ${pkgs[@]}; do
		checkPackageDB extra ${pkgbase} 1-1
	done
}

@test "add any packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
		__movePackageToRepo extra ${pkgbase} any
		db-repo-add extra any ${pkgbase}-1-1-any${PKGEXT}
	done

	for pkgbase in ${pkgs[@]}; do
		checkPackageDB extra "${pkgbase}" 1-1
	done
}
