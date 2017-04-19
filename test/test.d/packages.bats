load ../lib/common

@test "testPackages" {
	local result
	local pkg
	local pkgbase
	local pkgarchs
	local pkgarch
	local tmp=$(mktemp -d)

	# FIXME: Evaluate if this test is sane and even needed

	cp -r packages/* ${tmp}

	for pkgbase in ${tmp}/*; do
		pushd ${pkgbase}
		# FIXME: Is overriding IFS a bats bug?
		IFS=' '
		pkgarchs=($(. PKGBUILD; echo ${arch[@]}))
		for pkgarch in ${pkgarchs[@]}; do
			echo Building ${pkgbase} on ${pkgarch}
				run namcap -e pkgnameindesc,tags PKGBUILD
				[ -z "$output" ]

				CARCH=${arch} makepkg -cf

				for pkg in *${PKGEXT}; do
					run namcap -e pkgnameindesc ${pkg}
					[ -z "$output" ]
				done
		done
		popd
	done
}
