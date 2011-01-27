#!/bin/bash

curdir=$(readlink -e $(dirname $0))
. "${curdir}/../lib/common.inc"

testAddSimplePackages() {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
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
			checkPackage extra ${pkgbase}-1-1-${arch}.pkg.tar.xz ${arch}
		done
	done
}

testAddSingleSimplePackage() {
	releasePackage extra 'pkg-simple-a' 'i686'
	../db-update
	checkPackage extra 'pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
}

testAddAnyPackages() {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase} any
	done

	../db-update

	for pkgbase in ${pkgs[@]}; do
		checkAnyPackage extra ${pkgbase}-1-1-any.pkg.tar.xz
	done
}

testAddSplitPackages() {
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

	../db-update

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			for pkg in "${pkgdir}/${pkgbase}"/*-${arch}.pkg.tar.*; do
				checkPackage extra $(basename ${pkg}) ${arch}
			done
		done
	done
}

testUpdateAnyPackage() {
	releasePackage extra pkg-any-a any
	../db-update

	pushd "${TMP}/svn-packages-copy/pkg-any-a/trunk/" >/dev/null
	sed 's/pkgrel=1/pkgrel=2/g' -i PKGBUILD
	svn commit -q -m"update pkg to pkgrel=2" >/dev/null
	extra-i686-build >/dev/null 2>&1
	mv pkg-any-a-1-2-any.pkg.tar.xz "${pkgdir}/pkg-any-a/"
	popd >/dev/null

	releasePackage extra pkg-any-a any
	../db-update

	checkAnyPackage extra pkg-any-a-1-2-any.pkg.tar.xz any

	rm -f "${pkgdir}/pkg-any-a/pkg-any-a-1-2-any.pkg.tar.xz"
}

testUpdateAnyPackageToDifferentRepositoriesAtOnce() {
	releasePackage extra pkg-any-a any

	pushd "${TMP}/svn-packages-copy/pkg-any-a/trunk/" >/dev/null
	sed 's/pkgrel=1/pkgrel=2/g' -i PKGBUILD
	svn commit -q -m"update pkg to pkgrel=2" >/dev/null
	extra-i686-build >/dev/null 2>&1
	mv pkg-any-a-1-2-any.pkg.tar.xz "${pkgdir}/pkg-any-a/"
	popd >/dev/null

	releasePackage testing pkg-any-a any

	../db-update

	checkAnyPackage extra pkg-any-a-1-1-any.pkg.tar.xz any
	checkAnyPackage testing pkg-any-a-1-2-any.pkg.tar.xz any

	rm -f "${pkgdir}/pkg-any-a/pkg-any-a-1-2-any.pkg.tar.xz"
}

testUpdateSameAnyPackageToSameRepository() {
	releasePackage extra pkg-any-a any
	../db-update
	checkAnyPackage extra pkg-any-a-1-1-any.pkg.tar.xz any

	releasePackage extra pkg-any-a any
	../db-update >/dev/null 2>&1 && (fail 'Adding an existing package to the same repository should fail'; return 1)
}

testUpdateSameAnyPackageToDifferentRepositories() {
	releasePackage extra pkg-any-a any
	../db-update
	checkAnyPackage extra pkg-any-a-1-1-any.pkg.tar.xz any

	releasePackage testing pkg-any-a any
	../db-update >/dev/null 2>&1 && (fail 'Adding an existing package to another repository should fail'; return 1)

	local arch
	for arch in i686 x86_64; do
		( [ -r "${FTP_BASE}/testing/os/${arch}/testing${DBEXT%.tar.*}" ] \
			&& bsdtar -xf "${FTP_BASE}/testing/os/${arch}/testing${DBEXT%.tar.*}" -O | grep -q ${pkgbase}) \
			&& fail "${pkgbase} should not be in testing/os/${arch}/testing${DBEXT%.tar.*}"
	done
}


testAddIncompleteSplitPackage() {
	local arches=('i686' 'x86_64')
	local repo='extra'
	local pkgbase='pkg-split-a'
	local arch

	for arch in ${arches[@]}; do
		releasePackage ${repo} ${pkgbase} ${arch}
	done

	# remove a split package to make db-update fail
	rm "${STAGING}"/extra/${pkgbase}1-*

	../db-update >/dev/null 2>&1 && fail "db-update should fail when a split package is missing!"

	for arch in ${arches[@]}; do
		( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" ] \
		&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" -O | grep -q ${pkgbase}) \
		&& fail "${pkgbase} should not be in ${repo}/os/${arch}/${repo}${DBEXT%.tar.*}"
	done
}

. "${curdir}/../lib/shunit2"
