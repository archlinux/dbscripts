#!/hint/bash

# usage: vcsSetup
# Do any test-suite setup.
#
# Count on $TMP and $DBSCRIPTS_CONFIG being set, but not much else
# being done.  Notably $DBSCRIPTS_CONFIG hasn't been loaded yet (so
# that we have a chance to edit it).
vcsSetup() {
	cat <<eot >> "${DBSCRIPTS_CONFIG}"
	SVNREPO="file://${TMP}/svn-packages-repo"
eot

	mkdir -p "${TMP}"/svn-packages-{copy,repo}

	svnadmin create "${TMP}/svn-packages-repo"
	svn checkout -q "file://${TMP}/svn-packages-repo" "${TMP}/svn-packages-copy"
}

# usage: vcsDirOfPKGBUILD $pkgbase
#
# Print the path to the directory storing the "trunk"/"master" working
# copy of the PKGBUILD for the given $pkgbase.
vcsDirOfPKGBUILD() {
	local pkgbase=$1

	echo "${TMP}/svn-packages-copy/${pkgbase}/trunk/"
}

# usage: vcsInitFixture $pkgbase
#
# Initialize from the test fixtures the "trunk"/"master" working copy
# of the PKGBUILD for the given $pkgbase.
vcsInitFixture() {
	local pkgbase=$1

	mkdir -p "${TMP}/svn-packages-copy/${pkgbase}"/{trunk,repos}
	cp -r "fixtures/${pkgbase}"/* "${TMP}/svn-packages-copy/${pkgbase}/trunk/"
	svn add -q "${TMP}/svn-packages-copy/${pkgbase}"
	svn commit -q -m"initial commit of ${pkgbase}" "${TMP}/svn-packages-copy"
}

# usage: vcsCommit $msg
# Commit changes to the PKGBUILD in the current directory
vcsCommit() {
	local msg=$1
	svn commit -q -m"$msg"
}

# usage: vcsRelease $repo
# Run from the "trunk"/"master" PKGBUILD directory.
#
# This is a cheap imitation of the `archrelease` program that is part
# of the `devtools` package.
vcsRelease() {
	local repo=$1
	local pkgarches
	local tarch
	local tag

	pkgarches=($(. PKGBUILD; echo ${arch[@]}))
	pushd ..
	for tarch in ${pkgarches[@]}; do
		tag=${repo}-${tarch}

		if [[ -d repos/$tag ]]; then
			svn rm repos/$tag/PKGBUILD
		else
			mkdir -p repos/$tag
			svn add repos/$tag
		fi

		svn copy -r HEAD trunk/PKGBUILD repos/$tag/
	done
	svn commit -m "__archrelease"
	popd
}

# usage: vcsCheckPackage $repo $pkgbase $pkgver
#
# Verify that the PKGBUILD for the given $pkgbase is tagged as
# existing in $repo, and has the correct $pkgver.
vcsCheckPackage() {
	local repo=$1
	local pkgbase=$2
	local pkgver=$3

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"

	local dirarches=() pkgbuildarches=()
	local pkgbuild dirarch pkgbuildver
	for pkgbuild in "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-"+([^-])"/PKGBUILD"; do
		[[ -e $pkgbuild ]] || continue
		dirarch=${pkgbuild%/PKGBUILD}
		dirarch=${dirarch##*-}

		dirarches+=("$dirarch")
		pkgbuildarches+=($(. "$pkgbuild"; echo ${arch[@]}))
		pkgbuildver=$(. "$pkgbuild"; get_full_version)
		[[ $pkgver = "$pkgbuildver" ]]
	done
	# Verify that the arches-from-dirnames and
	# arches-from-PKGBUILDs agree (that a PKGBUILD existed for
	# every arch).
	(( ${#dirarches[@]} > 0 ))
	mapfile -d '' dirarches      < <(printf '%s\0' "${dirarches[@]}"      | sort -uz)
	mapfile -d '' pkgbuildarches < <(printf '%s\0' "${pkgbuildarches[@]}" | sort -uz)
	declare -p dirarches pkgbuildarches
	[[ "${dirarches[*]}" = "${pkgbuildarches[*]}" ]]
}

# usage: vcsCheckRemovedPackage $repo $pkgbase
#
# Verify that no PKGBUILD for the given $pkgbase is tagged as existing
# in $repo.
vcsCheckRemovedPackage() {
	local repo=$1
	local pkgbase=$2

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"

	if __isGlobfile "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-"+([^-])"/PKGBUILD"; then
		return 1
	fi
}
