testTesting2xAnyPackage() {
	releasePackage core pkg-any-a any
	../db-update

	updatePackage pkg-any-a

	releasePackage testing pkg-any-a any
	../db-update

	../testing2x pkg-any-a

	checkAnyPackage core pkg-any-a-1-2-any.pkg.tar.xz any
	checkRemovedAnyPackage testing pkg-any-a
}
