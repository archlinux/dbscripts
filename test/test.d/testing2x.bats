load ../lib/common

@test "testTesting2xAnyPackage" {
	releasePackage core pkg-any-a any
	db-update

	updatePackage pkg-any-a any

	releasePackage testing pkg-any-a any
	db-update

	testing2x pkg-any-a

	checkAnyPackage core pkg-any-a-1-2-any.pkg.tar.xz
	checkRemovedAnyPackage testing pkg-any-a
}
