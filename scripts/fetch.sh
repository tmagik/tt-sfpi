#! /bin/bash

# Script to automatically get a specified release.  Invoke from your build system providing
# VERSION ident
# MD5 file
# DST directory
# You probably want to extract VERSION from a file, not hard code it into your build script.

set -eo pipefail

if [[ "$#" != 3 ]] ; then
    echo "Usage: $0 VERSION MD5FILE DSTDIR" 1>&2
    exit 1
fi

ver=$1
md5=$2
dst=${3%/sfpi}

url=https://github.com/tenstorrent/sfpi/releases/download
file=$(cut -d' ' -f1 $md5)

if test -r $dst/sfpi/version && test "$ver" = "$(cat $dst/sfpi/version)" ; then
    # We have this already
    exit 0
fi

if which curl >/dev/null ; then
    fetcher="curl -L -o - --ftp-pasv --retry 10"
elif which wget > /dev/null ; then
    fetcher="wget -O -"
else
    echo "No downloader available" 1>&2
    exit 1
fi

echo "Downloading new sfpi release: $ver/$file"

(cd $dst && $fetcher $url/$ver/$file)
if ! (cd $dst ; md5sum -c -) < $md5 ; then
    echo "MD5 hash mismatch on $dst/$file" 1>&2
    exit 1
fi

(cd $dst && rm -rf sfpi && tar xzf $file)
cp $md5 $dst/sfpi
echo "$ver" > $dst/sfpi/version
rm -f $dst/$file
