#!/bin/bash

curdir=$(readlink -e $(dirname $0))
. "${curdir}/../lib/common.inc"

testCreateSimpleFileLists() {
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
			if ! bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra${FILESEXT}" | grep -q "usr/bin/${pkgbase}"; then
				fail "usr/bin/${pkgbase} not found in ${arch}/extra${FILESEXT}"
			fi
		done
	done
}

testCreateAnyFileLists() {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase} any
	done
	../db-update

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			if ! bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra${FILESEXT}" | grep -q "usr/share/${pkgbase}/test"; then
				fail "usr/share/${pkgbase}/test not found in ${arch}/extra${FILESEXT}"
			fi
		done
	done
}

testCreateSplitFileLists() {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-split-a' 'pkg-split-b')
	local pkg
	local pkgbase
	local pkgname
	local pkgnames
	local arch

	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			releasePackage extra ${pkgbase} ${arch}
		done
	done
	../db-update

	for pkgbase in ${pkgs[@]}; do
		pkgnames=($(source "${TMP}/svn-packages-copy/${pkgbase}/trunk/PKGBUILD"; echo ${pkgname[@]}))
		for pkgname in ${pkgnames[@]}; do
			for arch in ${arches[@]}; do
				if ! bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra${FILESEXT}" | grep -q "usr/bin/${pkgname}"; then
					fail "usr/bin/${pkgname} not found in ${arch}/extra${FILESEXT}"
				fi
			done
		done
	done
}


testCleanupFileLists() {
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

	for arch in ${arches[@]}; do
		../db-remove extra ${arch} pkg-simple-a
	done

	for arch in ${arches[@]}; do
		if ! bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra${FILESEXT}" | grep -q "usr/bin/pkg-simple-b"; then
			fail "usr/bin/pkg-simple-b not found in ${arch}/extra${FILESEXT}"
		fi
		if bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra${FILESEXT}" | grep -q "usr/bin/pkg-simple-a"; then
			fail "usr/bin/pkg-simple-a still found in ${arch}/extra${FILESEXT}"
		fi
	done

}

. "${curdir}/../lib/shunit2"
