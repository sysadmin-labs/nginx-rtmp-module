#!/bin/sh
#
# Was the fragment cleanup actually scheduled for an application that
# inherits its path?
#
# hls_cleanup is on by default, and the cleanup is registered in
# ngx_rtmp_hls_merge_app_conf only when conf->path is already filled in.
# The path used to be merged after that block, so an hls_path given in
# rtmp{} or server{} was still empty when the block looked at it: the
# cleanup was skipped for every application that inherited the path, and
# fragments were kept for ever.  Nothing failed and nothing was logged;
# the disk filled up weeks later.
#
#     ci/hls.sh <nginx binary>
#
# Set HLS_LOAD_MODULE to the path of the .so for a loadable build.
#
# WHAT IS ASSERTED, and why it is shaped this way:
#
#   nginx creates the directory named by hls_path and by dash_path at
#   startup.  That is a side effect of ngx_add_path, which is called in
#   the same block that schedules the cleanup and nowhere else, so the
#   directory existing is the only sign from outside that the block ran.
#   The directory is removed before the start, so its presence afterwards
#   cannot be left over from an earlier run.
#
#   The suite's own TEST 9 checks that the warning "hls is on but no
#   hls_path is set" stays away, which says the merge happened before the
#   warning.  It says nothing about the registration, and moving the merge
#   back below the cleanup block but above the warning would keep that
#   test green while the bug is back.  This is the gate that does not.
#
#   Both the inheriting application and the one with its own path are
#   checked, because the bug only ever affected the inheriting one.

set -eu

NGINX=${1:?path to the nginx binary missing}
SRC=$(cd "$(dirname "$0")/.." && pwd)
WORK=${CI_WORK:-$SRC/ci-work}/hls
PORT=${HLS_PORT:-18935}

rm -rf "$WORK"
mkdir -p "$WORK/conf" "$WORK/logs"

ngx_user=
if [ "$(id -u)" = 0 ]; then
	ngx_user="user root $(id -gn);"
fi

ngx_load=
if [ -n "${HLS_LOAD_MODULE:-}" ]; then
	ngx_load="load_module $HLS_LOAD_MODULE;"
fi

fail=0
note() {
	echo "  $1" >&2
	fail=1
}

# Deliberately not created here: nginx has to create them.
inherited=$WORK/hls-inherited
own=$WORK/hls-own
dash=$WORK/dash-inherited

cat > "$WORK/conf/nginx.conf" <<EOF
$ngx_load
$ngx_user
worker_processes 1;
error_log $WORK/logs/error.log info;
pid $WORK/logs/nginx.pid;
events { worker_connections 64; }
rtmp {
    server {
        listen 127.0.0.1:$PORT;

        # Set here, not in the application below: this is the case that
        # used to lose its cleanup.
        hls_path  $inherited;
        dash_path $dash;

        application inherits {
            live on;
            hls  on;
            dash on;
        }

        application owns {
            live on;
            hls  on;
            hls_path $own;
        }
    }
}
http {
    access_log off;
    server {
        listen 127.0.0.1:$((PORT + 1));
        location = /t { return 200 "ok\\n"; }
    }
}
EOF

echo "--- the configuration is read ---"
"$NGINX" -p "$WORK" -c conf/nginx.conf -t

"$NGINX" -p "$WORK" -c conf/nginx.conf
sleep 1

stop() {
	[ -s "$WORK/logs/nginx.pid" ] && kill "$(cat "$WORK/logs/nginx.pid")" 2> /dev/null
	return 0
}
trap stop EXIT

echo "--- nginx created the directories it was told to clean ---"
for d in "$inherited" "$own" "$dash"; do
	if [ -d "$d" ]; then
		echo "  $(basename "$d")"
	else
		note "$(basename "$d") was not created, so its path was never registered"
	fi
done

echo "--- and said nothing about a missing path ---"
if grep -q 'no hls_path is set\|no dash_path is set' "$WORK/logs/error.log" 2> /dev/null; then
	grep -n 'no hls_path is set\|no dash_path is set' "$WORK/logs/error.log" >&2
	note "see the lines above: the path was still empty at merge time"
else
	echo "  nothing"
fi

echo "--- no alert, no crit, no signal ---"
if grep -qE '\[alert\]|\[crit\]|SIGSEGV|SIGABRT|SIGBUS' "$WORK/logs/error.log" 2> /dev/null; then
	grep -nE '\[alert\]|\[crit\]|SIGSEGV|SIGABRT|SIGBUS' "$WORK/logs/error.log" | head -5 >&2
	note "see the lines above"
else
	echo "  none"
fi

[ "$fail" -eq 0 ]
