testPackages() {
	local result
	for pkg in $(find "${pkgdir}" -name "*${PKGEXT}"); do
		result=$(namcap -e pkgnameindesc ${pkg})
		[[ -n "${result}" ]] && fail "${result}"
	done;
}
