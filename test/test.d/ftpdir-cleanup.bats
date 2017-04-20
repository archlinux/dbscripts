load ../lib/common

@test "testCleanupSimplePackages" {
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

	for arch in ${arches[@]}; do
		db-remove extra ${arch} pkg-simple-a
	done

	ftpdir-cleanup

	for arch in ${arches[@]}; do
		local pkg1="pkg-simple-a-1-1-${arch}.pkg.tar.xz"
		checkRemovedPackage extra 'pkg-simple-a' ${arch}
		[ ! -f "${FTP_BASE}/${PKGPOOL}/${pkg1}" ]
		[ ! -f "${FTP_BASE}/${repo}/os/${arch}/${pkg1}" ]

		local pkg2="pkg-simple-b-1-1-${arch}.pkg.tar.xz"
		checkPackage extra ${pkg2} ${arch}
	done
}

@test "testCleanupEpochPackages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			releasePackage extra ${pkgbase} ${arch}
		done
	done

	db-update

	for arch in ${arches[@]}; do
		db-remove extra ${arch} pkg-simple-epoch
	done

	ftpdir-cleanup

	for arch in ${arches[@]}; do
		local pkg1="pkg-simple-epoch-1:1-1-${arch}.pkg.tar.xz"
		checkRemovedPackage extra 'pkg-simple-epoch' ${arch}
		[ ! -f "${FTP_BASE}/${PKGPOOL}/${pkg1}" ]
		[ ! -f "${FTP_BASE}/${repo}/os/${arch}/${pkg1}" ]
	done
}

@test "testCleanupAnyPackages" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase
	local arch='any'

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase} any
	done

	db-update
	db-remove extra any pkg-any-a
	ftpdir-cleanup

	local pkg1='pkg-any-a-1-1-any.pkg.tar.xz'
	checkRemovedPackage extra 'pkg-any-a' any
	[ ! -f "${FTP_BASE}/${PKGPOOL}/${pkg1}" ]
	[ ! -f "${FTP_BASE}/${repo}/os/${arch}/${pkg1}" ]

	local pkg2="pkg-any-b-1-1-${arch}.pkg.tar.xz"
	checkPackage extra ${pkg2} any
}

@test "testCleanupSplitPackages" {
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

	for arch in ${arches[@]}; do
		db-remove extra ${arch} ${pkgs[0]}
	done

	ftpdir-cleanup

	for arch in ${arches[@]}; do
		for pkg in $(getPackageNamesFromPackageBase ${pkgs[0]}); do
			checkRemovedPackage extra ${pkg} ${arch}
			[ ! -f "${FTP_BASE}/${PKGPOOL}/${pkg}" ]
			[ ! -f "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ]
		done

		for pkg in $(getPackageNamesFromPackageBase ${pkgs[1]}); do
			checkPackage extra ${pkg##*/} ${arch}
		done
	done
}

@test "testCleanupOldPackages" {
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

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			db-remove extra ${arch} ${pkgbase}
		done
	done

	ftpdir-cleanup

	local pkgfilea="pkg-simple-a-1-1-${arch}.pkg.tar.xz"
	local pkgfileb="pkg-simple-b-1-1-${arch}.pkg.tar.xz"
	for arch in ${arches[@]}; do
		touch -d "-$(expr ${CLEANUP_KEEP} + 1)days" ${CLEANUP_DESTDIR}/${pkgfilea}{,.sig}
	done

	ftpdir-cleanup

	[ ! -f ${CLEANUP_DESTDIR}/${pkgfilea} ]
	[ -f ${CLEANUP_DESTDIR}/${pkgfileb} ]
}
