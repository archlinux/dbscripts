#!/bin/bash

curdir=$(readlink -e $(dirname $0))
. "${curdir}/../lib/common.inc"

testSourceballs() {
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

	../cron-jobs/sourceballs
	for pkgbase in ${pkgs[@]}; do
		[ ! -r ${FTP_BASE}/${SRCPOOL}/${pkgbase}-*${SRCEXT} ] && fail "source package not found!"
	done
}

testAnySourceballs() {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase} any
	done
	../db-update

	../cron-jobs/sourceballs
	for pkgbase in ${pkgs[@]}; do
		[ ! -r ${FTP_BASE}/${SRCPOOL}/${pkgbase}-*${SRCEXT} ] && fail "source package not found!"
	done
}

testSplitSourceballs() {
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

	../cron-jobs/sourceballs
	for pkgbase in ${pkgs[@]}; do
		[ ! -r ${FTP_BASE}/${SRCPOOL}/${pkgbase}-*${SRCEXT} ] && fail "source package not found!"
	done
}

testSourceballsCleanup() {
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
	../cron-jobs/sourceballs

	for arch in ${arches[@]}; do
		../db-remove pkg-simple-a extra ${arch}
	done

	../cron-jobs/sourceballs
	[ -r ${FTP_BASE}/${SRCPOOL}/pkg-simple-a-*${SRCEXT} ] && fail "source package was not removed!"
	[ ! -r ${FTP_BASE}/${SRCPOOL}/pkg-simple-b-*${SRCEXT} ] && fail "source package not found!"
}

. "${curdir}/../lib/shunit2"
