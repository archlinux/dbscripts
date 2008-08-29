#!/bin/bash

parse() {
	unset pkgname pkgver pkgrel
	unset depends makedepends conflicts provides
	ret=0
	dir=$1
	pkgbuild=$dir/PKGBUILD
	source $pkgbuild &>/dev/null || ret=$?

	# ensure $pkgname and $pkgver variables were found
	if [ $ret -ne 0 -o -z "$pkgname" -o -z "$pkgver" ]; then
		echo -e "%INVALID%\n$pkgbuild\n"
		return 1
	fi 

	echo -e "%NAME%\n$pkgname\n"
	echo -e "%VERSION%\n$pkgver-$pkgrel\n"
	echo -e "%PATH%\n$dir\n"

	if [ -n "$arch" ]; then
		echo "%ARCH%"
		for i in ${arch[@]}; do echo $i; done
		echo ""
	fi
	if [ -n "$depends" ]; then
		echo "%DEPENDS%"
		for i in ${depends[@]}; do
			echo $i
		done
		echo ""
	fi
	if [ -n "$makedepends" ]; then
		echo "%MAKEDEPENDS%"
		for i in ${makedepends[@]}; do
			echo $i
		done
		echo ""
	fi
	if [ -n "$conflicts" ]; then
		echo "%CONFLICTS%"
		for i in ${conflicts[@]}; do echo $i; done
		echo ""
	fi
	if [ -n "$provides" ]; then
		echo "%PROVIDES%"
		for i in ${provides[@]}; do echo $i; done
		echo ""
	fi
	return 0
}

find_pkgbuilds() {
	if [ -f $1/PKGBUILD ]; then
		parse $1
		return
	fi
	empty=1
	for dir in $1/*; do
		if [ -d $dir ]; then
			find_pkgbuilds $dir
			unset empty
		fi
	done
	if [ -n "$empty" ]; then
		echo -e "%MISSING%\n$1\n"
	fi
}

if [ -z "$*" ]; then
	exit 1
fi

for dir in "$@"; do
	find_pkgbuilds $dir
done

exit 0
