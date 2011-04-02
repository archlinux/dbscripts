#!/bin/bash

curdir=$(readlink -e $(dirname $0))
. "${curdir}/../lib/common.inc"

testAddUnsignedPackage() {
	releasePackage extra 'pkg-simple-a' 'i686'
	# remove any signature
	rm "${STAGING}"/extra/*.sig
	../db-update >/dev/null 2>&1 && fail "db-update should fail when a signature is missing!"
}

. "${curdir}/../lib/shunit2"
