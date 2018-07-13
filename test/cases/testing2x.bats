load ../lib/common

@test "move any package" {
	releasePackage core pkg-any-a
	db-update

	updatePackage pkg-any-a

	releasePackage testing pkg-any-a
	db-update

	testing2x pkg-any-a

	checkPackage core pkg-any-a 1-2
	checkRemovedPackage testing pkg-any-a
}
