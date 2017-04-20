load ../lib/common

@test "testTesting2xAnyPackage" {
	releasePackage core pkg-any-a any
	db-update

	updatePackage pkg-any-a any

	releasePackage testing pkg-any-a any
	db-update

	testing2x pkg-any-a

	checkPackage core pkg-any-a-1-2-any.pkg.tar.xz any
	checkRemovedPackage testing pkg-any-a any
}
