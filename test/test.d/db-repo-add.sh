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

testAddMultiplePackages() {
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

. "${curdir}/../lib/shunit2"
