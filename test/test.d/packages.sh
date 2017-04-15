testPackages() {
	# TODO: namcap -r sodepends fails with i686 packages
	find "${pkgdir}" -name "*${PKGEXT}" -exec namcap -e sodepends,pkgnameindesc {} + || fail 'namcap failed'
}
