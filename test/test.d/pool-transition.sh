#!/bin/bash

curdir=$(readlink -e $(dirname $0))
. "${curdir}/../lib/common.inc"

testMovePackagesWithoutPool() {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-split-a' 'pkg-split-b')
	local pkgbase
	local arch
	local pkg
	local old

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			releasePackage testing ${pkgbase} ${arch}
		done
	done

	../db-update

	# transform two packages to old style layout
	for arch in ${arches[@]}; do
		for old in 0 2; do
			for pkg in "${pkgdir}/${pkgs[${old}]}"/*-${arch}${PKGEXT}; do
				pkg=$(basename $pkg)
				mv -f "${FTP_BASE}/${PKGPOOL}/${pkg}" "${FTP_BASE}/testing/os/${arch}/${pkg}"
			done
		done
	done

	../cron-jobs/ftpdir-cleanup >/dev/null

	../db-move testing extra ${pkgs[@]}

	../cron-jobs/ftpdir-cleanup >/dev/null

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			for pkg in "${pkgdir}/${pkgbase}"/*-${arch}${PKGEXT}; do
				checkPackage extra $(basename ${pkg}) ${arch}
			done
			checkRemovedPackage testing ${pkgbase} ${arch}
		done
	done
}

testUpdateAnyPackageWithoutPool() {
	local pkgname='pkg-any-a'
	local pkg1='pkg-any-a-1-1-any.pkg.tar.xz'
	local pkg2='pkg-any-a-1-2-any.pkg.tar.xz'
	local arch


	releasePackage extra pkg-any-a any
	../db-update
	# transform two packages to old style layout
	mv -f "${FTP_BASE}/${PKGPOOL}/${pkg1}" "${FTP_BASE}/extra/os/any"
	for arch in i686 x86_64; do
		ln -sf "../any/${pkg1}" "${FTP_BASE}/extra/os/${arch}"
	done

	pushd "${TMP}/svn-packages-copy/${pkgname}/trunk/" >/dev/null
	sed 's/pkgrel=1/pkgrel=2/g' -i PKGBUILD
	svn commit -q -m"update pkg to pkgrel=2" >/dev/null
	sudo extra-i686-build >/dev/null 2>&1
	mv "${pkg2}" "${pkgdir}/${pkgname}/"
	popd >/dev/null

	releasePackage extra ${pkgname} any
	../db-update
	rm -f "${pkgdir}/${pkgname}/${pkg2}"

	../cron-jobs/ftpdir-cleanup >/dev/null

	checkAnyPackage extra "${pkg2}"

	[ -f "${FTP_BASE}/${PKGPOOL}/${pkg1}" ] && fail "${PKGPOOL}/${pkg1} found"
	for arch in any i686 x86_64; do
		[ -f "${FTP_BASE}/extra/os/${arch}/${pkg1}" ] && fail "extra/os/${arch}/${pkg1} found"
	done
}

testMoveAnyPackagesWithoutPool() {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase
	local arch
	local pkg

	for pkgbase in ${pkgs[@]}; do
		releasePackage testing ${pkgbase} any
	done

	../db-update

	# transform a package to old style layout
	for pkg in "${pkgdir}/${pkgs[0]}"/*-any${PKGEXT}; do
		pkg=$(basename $pkg)
		mv -f "${FTP_BASE}/${PKGPOOL}/${pkg}" "${FTP_BASE}/testing/os/any/${pkg}"
		for arch in i686 x86_64; do
			ln -sf "../any/${pkg}" "${FTP_BASE}/testing/os/${arch}/${pkg}"
		done
	done

	../cron-jobs/ftpdir-cleanup >/dev/null

	../db-move testing extra ${pkgs[@]}

	../cron-jobs/ftpdir-cleanup >/dev/null

	for pkgbase in ${pkgs[@]}; do
		for pkg in "${pkgdir}/${pkgbase}"/*-any${PKGEXT}; do
			checkAnyPackage extra $(basename ${pkg})
		done
		checkRemovedAnyPackage testing ${pkgbase}
	done

	for pkg in "${pkgdir}/${pkgs[0]}"/*-any${PKGEXT}; do
		pkg=$(basename $pkg)
		for arch in any i686 x86_64; do
			[ -f "${FTP_BASE}/testing/os/${arch}/${pkg}" ] && fail "testing/os/${arch}/${pkg} found"
		done
	done
}

testUpdateSameAnyPackageToDifferentRepositoriesWithoutPool() {
	local pkg
	local arch

	releasePackage extra pkg-any-a any
	../db-update

	# transform a package to old style layout
	for pkg in "${pkgdir}/pkg-any-a"/*-any${PKGEXT}; do
		pkg=$(basename $pkg)
		mv -f "${FTP_BASE}/${PKGPOOL}/${pkg}" "${FTP_BASE}/extra/os/any/${pkg}"
		for arch in i686 x86_64; do
			ln -sf "../any/${pkg}" "${FTP_BASE}/extra/os/${arch}/${pkg}"
		done
	done

	releasePackage testing pkg-any-a any
	../db-update >/dev/null 2>&1 && (fail 'Adding an existing package to another repository should fail'; return 1)

	for arch in i686 x86_64; do
		( [ -r "${FTP_BASE}/testing/os/${arch}/testing${DBEXT%.tar.*}" ] \
			&& bsdtar -xf "${FTP_BASE}/testing/os/${arch}/testing${DBEXT%.tar.*}" -O | grep -q pkg-any-a) \
			&& fail "pkg-any-a should not be in testing/os/${arch}/testing${DBEXT%.tar.*}"
	done
}

. "${curdir}/../lib/shunit2"
