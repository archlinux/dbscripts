#!/bin/bash

curdir=$(readlink -e $(dirname $0))
. "${curdir}/../lib/common.inc"

testRemovePackages() {
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

testRemoveMultiplePackages() {
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

. "${curdir}/../lib/shunit2"
