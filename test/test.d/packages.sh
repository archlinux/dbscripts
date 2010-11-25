#!/bin/bash

curdir=$(readlink -e $(dirname $0))
. "${curdir}/../lib/common.inc"

testPackages() {
	# TODO: namcap -r depends fails with i686 packages
	find "${pkgdir}" -name "*${PKGEXT}" -exec namcap -e depends {} + || fail 'namcap failed'
}

. "${curdir}/../lib/shunit2"
