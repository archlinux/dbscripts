load ../lib/common

__getPackageNamesFromPackageBase() {
	local pkgbase=$1

	(. "fixtures/${pkgbase}/PKGBUILD"; echo ${pkgname[@]})
}

__checkRepoRemovedPackage() {
	local repo=$1
	local pkgbase=$2
	local repoarch=$3
	local pkgname

	for pkgname in $(__getPackageNamesFromPackageBase ${pkgbase}); do
		if __isGlobfile "${FTP_BASE}/${PKGPOOL}/${pkgname}"-*"${PKGEXT}"; then
			return 1
		fi
		if __isGlobfile "${FTP_BASE}/${DEBUGPKGPOOL}/${pkgname}"-debug-*"${PKGEXT}"; then
			return 1
		fi
		if __isGlobfile "${FTP_BASE}/${repo}/os/${repoarch}/${pkgname}"-*"${PKGEXT}"; then
			return 1
		fi
		if __isGlobfile "${FTP_BASE}/${repo}-debug/os/${repoarch}/${pkgname}"-debug-*"${PKGEXT}"; then
			return 1
		fi
	done
}

@test "cleanup simple packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for arch in ${arches[@]}; do
		db-remove extra ${arch} pkg-simple-a
	done

	ftpdir-cleanup

	checkRemovedPackage extra 'pkg-simple-a'
	for arch in ${arches[@]}; do
		__checkRepoRemovedPackage extra 'pkg-simple-a' ${arch}
	done

	checkPackage extra pkg-simple-b 1-1
}

@test "cleanup debug packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-debuginfo-a' 'pkg-debuginfo-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done
	db-update

	for arch in ${arches[@]}; do
		db-remove extra ${arch} "${pkgs[0]}"
	done

	ftpdir-cleanup

	checkRemovedPackage extra "${pkgs[0]}"
	checkRemovedPackage extra-debug "${pkgs[0]}"
	for arch in ${arches[@]}; do
		__checkRepoRemovedPackage extra "${pkgs[0]}" ${arch}
	done

	checkPackage extra "${pkgs[1]}" 1-1
	checkPackage extra-debug "${pkgs[1]}" 1-1
}

@test "cleanup epoch packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for arch in ${arches[@]}; do
		db-remove extra ${arch} pkg-simple-epoch
	done

	ftpdir-cleanup

	checkRemovedPackage extra 'pkg-simple-epoch'
	for arch in ${arches[@]}; do
		__checkRepoRemovedPackage extra 'pkg-simple-epoch' ${arch}
	done
}

@test "cleanup any packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase
	local arch='any'

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update
	db-remove extra any pkg-any-a
	ftpdir-cleanup

	local pkg1="pkg-any-a-1-1-any${PKGEXT}"
	checkRemovedPackage extra 'pkg-any-a'
	for arch in ${arches[@]}; do
		__checkRepoRemovedPackage extra 'pkg-any-a' ${arch}
	done

	checkPackage extra pkg-any-b 1-1
}

@test "cleanup split packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-split-a' 'pkg-split-b')
	local pkg
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for arch in ${arches[@]}; do
		db-remove extra ${arch} ${pkgs[0]}
	done

	ftpdir-cleanup

	for arch in ${arches[@]}; do
		__checkRepoRemovedPackage extra ${pkgs[0]} ${arch}
	done

	checkRemovedPackage extra ${pkgs[0]}
	checkPackage extra ${pkgs[1]} 1-1
}

@test "cleanup old packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
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

	ftpdir-cleanup

	local pkgfilea="pkg-simple-a-1-1-${arch}${PKGEXT}"
	local pkgfileb="pkg-simple-b-1-1-${arch}${PKGEXT}"
	for arch in ${arches[@]}; do
		touch -d "-$(expr ${CLEANUP_KEEP} + 1)days" ${CLEANUP_DESTDIR}/${pkgfilea}{,.sig}
	done

	ftpdir-cleanup

	[ ! -f ${CLEANUP_DESTDIR}/${pkgfilea} ]
	[ -f ${CLEANUP_DESTDIR}/${pkgfileb} ]
}

@test "cleanup debug packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-debuginfo' 'pkg-split-debuginfo')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for arch in ${arches[@]}; do
		db-remove extra ${arch} pkg-debuginfo
	done

	ftpdir-cleanup

	checkRemovedPackage extra 'pkg-debuginfo'
	for arch in ${arches[@]}; do
		__checkRepoRemovedPackage extra 'pkg-debuginfo' ${arch}
	done

	checkPackage extra pkg-split-debuginfo 1-1
}
