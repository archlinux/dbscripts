#!/bin/bash

curdir=$(readlink -e $(dirname $0))
. "${curdir}/../lib/common.inc"

testMoveSimplePackages() {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			releasePackage testing ${pkgbase} ${arch}
		done
	done

	../db-update

	../db-move testing extra pkg-simple-a

	for arch in ${arches[@]}; do
		checkPackage extra pkg-simple-a-1-1-${arch}.pkg.tar.xz ${arch}
		checkRemovedPackage testing pkg-simple-a-1-1-${arch}.pkg.tar.xz ${arch}

		checkPackage testing pkg-simple-b-1-1-${arch}.pkg.tar.xz ${arch}
	done
}

testMoveEpochPackages() {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			releasePackage testing ${pkgbase} ${arch}
		done
	done

	../db-update

	../db-move testing extra pkg-simple-epoch

	for arch in ${arches[@]}; do
		checkPackage extra pkg-simple-epoch-1:1-1-${arch}.pkg.tar.xz ${arch}
		checkRemovedPackage testing pkg-simple-epoch-1:1-1-${arch}.pkg.tar.xz ${arch}
	done
}

testMoveAnyPackages() {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in ${pkgs[@]}; do
		releasePackage testing ${pkgbase} any
	done

	../db-update
	../db-move testing extra pkg-any-a

	checkAnyPackage extra pkg-any-a-1-1-any.pkg.tar.xz
	checkRemovedAnyPackage testing pkg-any-a
	checkAnyPackage testing pkg-any-b-1-1-any.pkg.tar.xz
}

testMoveSplitPackages() {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-split-a' 'pkg-split-b')
	local pkg
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			releasePackage testing ${pkgbase} ${arch}
		done
	done

	../db-update
	../db-move testing extra pkg-split-a

	for arch in ${arches[@]}; do
		for pkg in "${pkgdir}/pkg-split-a"/*-${arch}${PKGEXT}; do
			checkPackage extra $(basename ${pkg}) ${arch}
		done
	done
	for arch in ${arches[@]}; do
		for pkg in "${pkgdir}/pkg-split-b"/*-${arch}${PKGEXT}; do
			checkPackage testing $(basename ${pkg}) ${arch}
		done
	done

	checkRemovedAnyPackage testing pkg-split-a
}

. "${curdir}/../lib/shunit2"
