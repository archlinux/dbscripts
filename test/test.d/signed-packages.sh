testAddSignedPackage() {
	releasePackage extra 'pkg-simple-a' 'i686'
	../db-update || fail "db-update failed!"
}

testAddUnsignedPackageFails() {
	releasePackage extra 'pkg-simple-a' 'i686'
	rm "${STAGING}"/extra/*.sig
	../db-update >/dev/null 2>&1 && fail "db-update should fail when a signature is missing!"

	checkRemovedPackage extra pkg-simple-a-1-1-i686.pkg.tar.xz i686
}

testAddInvalidSignedPackageFails() {
	local p
	releasePackage extra 'pkg-simple-a' 'i686'
	for p in "${STAGING}"/extra/*${PKGEXT}; do
		unxz $p
		xz -0 ${p%%.xz}
	done
	../db-update >/dev/null 2>&1 && fail "db-update should fail when a signature is invalid!"

	checkRemovedPackage extra pkg-simple-a-1-1-i686.pkg.tar.xz i686
}

testAddBrokenSignatureFails() {
	local s
	releasePackage extra 'pkg-simple-a' 'i686'
	for s in "${STAGING}"/extra/*.sig; do
		echo 0 > $s
	done
	../db-update >/dev/null 2>&1 && fail "db-update should fail when a signature is broken!"

	checkRemovedPackage extra pkg-simple-a-1-1-i686.pkg.tar.xz i686
}
