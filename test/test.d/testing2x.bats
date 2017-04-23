load ../lib/common

@test "testTesting2xAnyPackage" {
	releasePackage core pkg-any-a
	db-update

	updatePackage pkg-any-a

	releasePackage testing pkg-any-a
	db-update

	testing2x pkg-any-a

	checkPackage core pkg-any-a
	checkRemovedPackage testing pkg-any-a
}
