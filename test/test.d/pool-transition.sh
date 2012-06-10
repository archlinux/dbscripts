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
				pkg=${pkg##*/}
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
				checkPackage extra ${pkg##*/} ${arch}
			done
			checkRemovedPackage testing ${pkgbase} ${arch}
		done
	done
}

. "${curdir}/../lib/shunit2"
