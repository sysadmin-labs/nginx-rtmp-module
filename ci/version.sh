#!/bin/sh
#
# The version this module reports has to be the version this repository is.
#
# src/ngx_rtmp_version.h is a file upstream generated and then left behind:
# it said 1.1.4 while the module had moved on, and because
# ngx_rtmp_stat_module puts the value into the statistics page as
# <nginx_rtmp_version>, where stat.xsl renders it, that stale number was
# published to anybody who opened the page.  Nothing failed, so nothing
# drew attention to it for several releases.
#
#     ci/version.sh
#
# CHANGELOG.md is the source of truth, because that is the file a release
# cannot be made without touching.

set -eu

SRC=$(cd "$(dirname "$0")/.." && pwd)

want=$(sed -n 's/^## \([0-9][0-9.]*\)$/\1/p' "$SRC/CHANGELOG.md" | head -1)
[ -n "$want" ] || {
	echo "ci/version.sh: no version heading in CHANGELOG.md" >&2
	exit 1
}

hdr=$SRC/src/ngx_rtmp_version.h

got=$(sed -n 's/^#define NGINX_RTMP_VERSION  *"\(.*\)"/\1/p' "$hdr")
if [ "$got" != "$want" ]; then
	echo "ci/version.sh: NGINX_RTMP_VERSION is \"$got\", CHANGELOG.md says \"$want\"" >&2
	exit 1
fi

# The numeric form nginx uses for comparisons: major * 1000000 +
# minor * 1000 + patch, the same arithmetic as nginx_version itself.
want_num=$(echo "$want" | awk -F. '{printf "%d%03d%03d", $1, $2, $3}')
got_num=$(sed -n 's/^#define nginx_rtmp_version  *\([0-9]*\)/\1/p' "$hdr")
if [ "$got_num" != "$want_num" ]; then
	echo "ci/version.sh: nginx_rtmp_version is $got_num, $want means $want_num" >&2
	exit 1
fi

echo "ci/version.sh: $want, and the header agrees"
