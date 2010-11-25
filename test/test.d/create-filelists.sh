#!/bin/bash

curdir=$(readlink -e $(dirname $0))
. "${curdir}/../lib/common.inc"

testCreateSimpleFileLists() {
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

	../cron-jobs/create-filelists
	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			if ! bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra.files.tar.gz" | grep -q "usr/bin/${pkgbase}"; then
				fail "usr/bin/${pkgbase} not found in ${arch}/extra.files.tar.gz"
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

	../cron-jobs/create-filelists
	for pkgbase in ${pkgs[@]}; do
		for arch in ${arches[@]}; do
			if ! bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra.files.tar.gz" | grep -q "usr/share/${pkgbase}/test"; then
				fail "usr/share/${pkgbase}/test not found in ${arch}/extra.files.tar.gz"
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

	../cron-jobs/create-filelists
	for pkgbase in ${pkgs[@]}; do
		pkgnames=($(source "${TMP}/svn-packages-copy/${pkgbase}/trunk/PKGBUILD"; echo ${pkgname[@]}))
		for pkgname in ${pkgnames[@]}; do
			for arch in ${arches[@]}; do
				if ! bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra.files.tar.gz" | grep -q "usr/bin/${pkgname}"; then
					fail "usr/bin/${pkgname} not found in ${arch}/extra.files.tar.gz"
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
	../cron-jobs/create-filelists

	for arch in ${arches[@]}; do
		../db-remove pkg-simple-a extra ${arch}
	done
	../cron-jobs/create-filelists

	for arch in ${arches[@]}; do
		if ! bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra.files.tar.gz" | grep -q "usr/bin/pkg-simple-b"; then
			fail "usr/bin/pkg-simple-b not found in ${arch}/extra.files.tar.gz"
		fi
		if bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra.files.tar.gz" | grep -q "usr/bin/pkg-simple-a"; then
			fail "usr/bin/pkg-simple-a still found in ${arch}/extra.files.tar.gz"
		fi
	done

}

. "${curdir}/../lib/shunit2"
