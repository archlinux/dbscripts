#!/bin/bash

usage() {
  echo "Usage: $0 repo architecture"
}

getpkgname() {
  local tmp

  tmp=${1##*/}
  tmp=${tmp%.pkg.tar.gz}
  tmp=${tmp%-i686}
  tmp=${tmp%-x86_64}
  echo ${tmp%-*-*}
}

FTPBASEDIR="/home/ftp"
FTPDIR=${FTPBASEDIR}/${1}/os/${2}
DBFILE=${FTPDIR}/${1}.db.tar.gz
OBSOLETEFILES=""

if [ $# -lt 2 -o ! -f ${DBFILE} ]; then
  usage
  exit 1
fi

TMPDIR=$(mktemp -d /tmp/cleanup.XXXXXX) || exit 1
cd ${TMPDIR}
tar xzf ${DBFILE}

cd ${FTPDIR}
for pkgfile in *.pkg.tar.gz; do
  pkgname="$(getpkgname ${pkgfile})"
  for p in ${FTPDIR}/${pkgname}-*; do
    if [ "$(getpkgname $(basename ${p}))" = "${pkgname}" ]; then
      continue 2
    fi
  done
  OBSOLETEFILES="${OBSOLETEFILES} ${pkgfile}"
done

cd - >/dev/null
rm -rf ${TMPDIR}

echo -ne "DIRECTORY:\n${FTPDIR}\n\n"
echo -ne "OBSOLETEFILES:\n${OBSOLETEFILES}\n\n"
