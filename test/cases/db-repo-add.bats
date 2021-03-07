load ../lib/common

__movePackageToRepo() {
	local repo=$1
	local pkgbase=$2
	local arch=$3
	local tarch
	local tarches
	local is_debug=0

	if [[ $arch == any ]]; then
		tarches=(${ARCHES[@]})
	else
		tarches=(${arch})
	fi

	# FIXME: pkgbase might not be part of the package filename
	if __isGlobfile "${STAGING}"/${repo}/${pkgbase}-debug-*-*-${arch}${PKGEXT}; then
		mv -v "${STAGING}"/${repo}/${pkgbase}-debug-*-*-${arch}${PKGEXT}{,.sig} "${FTP_BASE}/${PKGPOOL}-debug/"
		is_debug=1
	fi
	mv -v "${STAGING}"/${repo}/${pkgbase}-*-*-${arch}${PKGEXT}{,.sig} "${FTP_BASE}/${PKGPOOL}/"
	for tarch in ${tarches[@]}; do
		ln -sv ${FTP_BASE}/${PKGPOOL}/${pkgbase}-*-*-${arch}${PKGEXT} "${FTP_BASE}/${repo}/os/${tarch}/"
		ln -sv ${FTP_BASE}/${PKGPOOL}/${pkgbase}-*-*-${arch}${PKGEXT}.sig "${FTP_BASE}/${repo}/os/${tarch}/"
		if ((is_debug)); then
			ln -sv ${FTP_BASE}/${PKGPOOL}-debug/${pkgbase}-*-*-${arch}${PKGEXT} "${FTP_BASE}/${repo}-debug/os/${tarch}/"
			ln -sv ${FTP_BASE}/${PKGPOOL}-debug/${pkgbase}-*-*-${arch}${PKGEXT}.sig "${FTP_BASE}/${repo}-debug/os/${tarch}/"
		fi
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

@test "add debug packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-debuginfo')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
		for arch in ${arches[@]}; do
			__movePackageToRepo extra ${pkgbase} ${arch}
			db-repo-add extra ${arch} ${pkgbase}-1-1-${arch}${PKGEXT}
			db-repo-add extra-debug ${arch} ${pkgbase}-debug-1-1-${arch}${PKGEXT}
		done
	done

	checkPackageDB extra ${pkgbase} 1-1
	checkPackageDB extra-debug ${pkgbase} 1-1
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
