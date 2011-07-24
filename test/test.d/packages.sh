#!/bin/bash

curdir=$(readlink -e $(dirname $0))
. "${curdir}/../lib/common.inc"

testPackages() {
	# TODO: namcap -r sodepends fails with i686 packages
	find "${pkgdir}" -name "*${PKGEXT}" -exec namcap -e sodepends,pkgnameindesc {} + || fail 'namcap failed'
}

. "${curdir}/../lib/shunit2"
