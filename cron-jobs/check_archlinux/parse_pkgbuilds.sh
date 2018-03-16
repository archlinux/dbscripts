#!/bin/bash

# Usage : parse_pkgbuilds.sh arch <pkgbuilds_dir1,dir2,...>
# Example : parse_pkgbuilds.sh x86_64 /var/abs/core /var/abs/extra

exit() { return; }

splitpkg_overrides=('depends' 'optdepends' 'provides' 'conflicts')
variables=('pkgname' 'pkgbase' 'epoch' 'pkgver' 'pkgrel' 'makedepends' 'arch' "${splitpkg_overrides[@]}")
readonly -a variables splitpkg_overrides

backup_package_variables() {
	for var in "${splitpkg_overrides[@]}"; do
		declare -p "$var" 2>/dev/null || printf 'unset %q\n' "$var"
	done
}

print_info() {
	echo -e "%NAME%\n$pkgname\n"
	if [ -n "$epoch" ]; then
		echo -e "%VERSION%\n$epoch:$pkgver-$pkgrel\n"
	else
		echo -e "%VERSION%\n$pkgver-$pkgrel\n"
	fi
	echo -e "%PATH%\n$dir\n"

	if [ -n "$pkgbase" ]; then
		echo -e "%BASE%\n$pkgbase\n"
	fi

	if [ -n "$arch" ]; then
		echo "%ARCH%"
		for i in "${arch[@]}"; do echo "$i"; done
		echo ""
	fi
	if [ -n "$depends" ]; then
		echo "%DEPENDS%"
		for i in "${depends[@]}"; do
			echo "$i"
		done
		echo ""
	fi
	if [ -n "$makedepends" ]; then
		echo "%MAKEDEPENDS%"
		for i in "${makedepends[@]}"; do
			echo "$i"
		done
		echo ""
	fi
	if [ -n "$conflicts" ]; then
		echo "%CONFLICTS%"
		for i in "${conflicts[@]}"; do echo "$i"; done
		echo ""
	fi
	if [ -n "$provides" ]; then
		echo "%PROVIDES%"
		for i in "${provides[@]}"; do echo "$i"; done
		echo ""
	fi
}

source_pkgbuild() {
	local restore_package_variables
	ret=0
	dir=$1
	pkgbuild=$dir/PKGBUILD
	for var in "${variables[@]}"; do
		unset "${var}"
	done
	source "$pkgbuild" &>/dev/null || ret=$?

	# ensure $pkgname and $pkgver variables were found
	if [ $ret -ne 0 -o -z "$pkgname" -o -z "$pkgver" ]; then
		echo -e "%INVALID%\n$pkgbuild\n"
		return 1
	fi

	if [ "${#pkgname[@]}" -gt "1" ]; then
		pkgbase=${pkgbase:-${pkgname[0]}}
		for pkg in "${pkgname[@]}"; do
			if [ "$(type -t "package_${pkg}")" != "function" ]; then
				echo -e "%INVALID%\n$pkgbuild\n"
				return 1
			else
				restore_package_variables=$(backup_package_variables)
				pkgname=$pkg
				while IFS= read -r line; do
					var=${line%%=*}
					var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
					for realvar in "${variables[@]}"; do
						if [ "$var" == "$realvar" ]; then
							eval $line
							break
						fi
					done
				done < <(type "package_${pkg}")
				print_info
				eval "$restore_package_variables"
			fi
		done
	else
		echo
		print_info
	fi

	return 0
}

find_pkgbuilds() {
	#Skip over some dirs
	local d="${1##*/}"
	if [ "$d" = "CVS" -o "$d" = ".svn" ]; then
		return
	fi

	if [ -f "$1/PKGBUILD" ]; then
		source_pkgbuild "$1"
		return
	fi
	empty=1
	for dir in "$1"/*; do
		if [ -d "$dir" ]; then
			find_pkgbuilds "$dir"
			unset empty
		fi
	done
	if [ -n "$empty" ]; then
		echo -e "%MISSING%\n$1\n"
	fi
}

if [ -z "$1" -o -z "$2" ]; then
	exit 1
fi

CARCH=$1
shift
for dir in "$@"; do
	find_pkgbuilds "$dir"
done

exit 0
