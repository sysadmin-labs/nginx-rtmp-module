# nginx-rtmp-module

[![Build][build-test-badge]][build-test-link]
[![Lint][lint-badge]][lint-link]
[![CodeQL][codeql-badge]][codeql-link]
[![A/UBSan][sanitizers-badge]][sanitizers-link]
[![Valgrind][valgrind-badge]][valgrind-link]
[![Reload][reload-badge]][reload-link]
[![FreeBSD][freebsd-badge]][freebsd-link]

[build-test-badge]: https://github.com/sysadmin-labs/nginx-rtmp-module/actions/workflows/build-test.yml/badge.svg
[build-test-link]: https://github.com/sysadmin-labs/nginx-rtmp-module/actions/workflows/build-test.yml
[lint-badge]: https://github.com/sysadmin-labs/nginx-rtmp-module/actions/workflows/lint.yml/badge.svg
[lint-link]: https://github.com/sysadmin-labs/nginx-rtmp-module/actions/workflows/lint.yml
[codeql-badge]: https://github.com/sysadmin-labs/nginx-rtmp-module/actions/workflows/codeql.yml/badge.svg
[codeql-link]: https://github.com/sysadmin-labs/nginx-rtmp-module/actions/workflows/codeql.yml
[sanitizers-badge]: https://github.com/sysadmin-labs/nginx-rtmp-module/actions/workflows/sanitizers.yml/badge.svg
[sanitizers-link]: https://github.com/sysadmin-labs/nginx-rtmp-module/actions/workflows/sanitizers.yml
[valgrind-badge]: https://github.com/sysadmin-labs/nginx-rtmp-module/actions/workflows/valgrind.yml/badge.svg
[valgrind-link]: https://github.com/sysadmin-labs/nginx-rtmp-module/actions/workflows/valgrind.yml
[reload-badge]: https://github.com/sysadmin-labs/nginx-rtmp-module/actions/workflows/reload.yml/badge.svg
[reload-link]: https://github.com/sysadmin-labs/nginx-rtmp-module/actions/workflows/reload.yml
[freebsd-badge]: https://github.com/sysadmin-labs/nginx-rtmp-module/actions/workflows/freebsd.yml/badge.svg
[freebsd-link]: https://github.com/sysadmin-labs/nginx-rtmp-module/actions/workflows/freebsd.yml

An RTMP server inside nginx: take a live stream in, relay it, record it,
and serve it again as HLS or MPEG-DASH, with a statistics and a control
endpoint over HTTP.

## Requirements

nginx 1.28 or newer, and OpenSSL, which the module's handshake needs.
`ffmpeg` only if `exec` is used to transcode.

## Building

```sh
./configure --add-module=/path/to/nginx-rtmp-module
```

As a loadable module, `--add-dynamic-module=` and then

```nginx
load_module modules/ngx_rtmp_module.so;
```

One object carries both the rtmp core modules and the two HTTP ones.

## Quick start

```nginx
rtmp {
    server {
        listen 1935;
        chunk_size 4096;

        application live {
            live on;
            record off;

            hls      on;
            hls_path /var/db/nginx/hls;
            hls_fragment 3s;
            hls_playlist_length 60s;
        }
    }
}

http {
    server {
        listen 8080;

        location /hls {
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            root /var/db/nginx;
            add_header Cache-Control no-cache;
        }

        location /stat {
            rtmp_stat all;
            rtmp_stat_stylesheet stat.xsl;
        }

        location /stat.xsl {
            root /usr/local/share/nginx/rtmp;
        }
    }
}
```

Publish to `rtmp://host/live/streamname` and the playlist appears at
`http://host:8080/hls/streamname.m3u8`.

**`hls_path` belongs where the application can see it**, and since the fix
above that includes inheriting it from `server{}`. Give it explicitly in
either place; `hls on` alone writes nothing.

## Directives

117 of them, read out of the modules' own command tables, so this is the
whole set and the contexts are the ones the code enforces. The shape of a
configuration: `rtmp{}` holds `server{}` blocks, a server holds
`application{}` blocks, and an application is where `live`, `record`,
`pull`, `push`, `exec`, `hls` and `dash` go. `rtmp_stat` and `rtmp_control`
are HTTP locations, not rtmp ones.

**`hls_path` and `dash_path` are inherited**, from `rtmp{}` or from
`server{}`, and that is worth saying because it did not work until this
release: an application that inherited the path got no cleanup handler, so
its fragments were never removed. `hls on` with no path anywhere now logs a
warning rather than writing nothing in silence.

### The server and the connection

|Directive|Context|Takes|
|---|---|---|
|`ack_window`|rtmp, server|1 argument|
|`application`|server|1 argument, a block|
|`buflen`|rtmp, server|1 argument|
|`busy`|rtmp, server|1 argument|
|`chunk_size`|rtmp, server|1 argument|
|`listen`|server|1 or 2 arguments|
|`max_message`|rtmp, server|1 argument|
|`max_streams`|rtmp, server|1 argument|
|`meta`|rtmp, server, application|1 argument|
|`out_cork`|rtmp, server|1 argument|
|`out_queue`|rtmp, server|1 argument|
|`ping`|rtmp, server|1 argument|
|`ping_timeout`|rtmp, server|1 argument|
|`play_time_fix`|rtmp, server, application|1 argument|
|`publish_time_fix`|rtmp, server, application|1 argument|
|`rtmp`|main|no arguments, a block|
|`server`|rtmp|no arguments, a block|
|`so_keepalive`|rtmp, server|on \| off, deprecated|
|`timeout`|rtmp, server|1 argument|

`so_keepalive` is marked deprecated in the module's own command table, so
nginx logs a warning and points at the `so_keepalive` parameter of
`listen` instead. It still works; use the `listen` parameter.

### Live streaming

|Directive|Context|Takes|
|---|---|---|
|`buffer`|rtmp, server, application|1 argument|
|`drop_idle_publisher`|rtmp, server, application|1 argument|
|`idle_streams`|rtmp, server, application|1 argument|
|`interleave`|rtmp, server, application|1 argument|
|`live`|rtmp, server, application|1 argument|
|`play_restart`|rtmp, server, application|1 argument|
|`publish_notify`|rtmp, server, application|1 argument|
|`stream_buckets`|rtmp, server, application|1 argument|
|`sync`|rtmp, server, application|1 argument|
|`wait_key`|rtmp, server, application|1 argument|
|`wait_video`|rtmp, server, application|1 argument|

### Recording

|Directive|Context|Takes|
|---|---|---|
|`record`|rtmp, server, application, recorder|1 or more arguments|
|`record_append`|rtmp, server, application, recorder|1 argument|
|`record_interval`|rtmp, server, application, recorder|1 argument|
|`record_lock`|rtmp, server, application, recorder|1 argument|
|`record_max_frames`|rtmp, server, application, recorder|1 argument|
|`record_max_size`|rtmp, server, application, recorder|1 argument|
|`record_notify`|rtmp, server, application, recorder|1 argument|
|`record_path`|rtmp, server, application, recorder|1 argument|
|`record_suffix`|rtmp, server, application, recorder|1 argument|
|`record_unique`|rtmp, server, application, recorder|1 argument|
|`recorder`|application|1 argument, a block|

### HLS

|Directive|Context|Takes|
|---|---|---|
|`hls`|rtmp, server, application|1 argument|
|`hls_audio_buffer_size`|rtmp, server, application|1 argument|
|`hls_base_url`|rtmp, server, application|1 argument|
|`hls_cleanup`|rtmp, server, application|1 argument|
|`hls_continuous`|rtmp, server, application|1 argument|
|`hls_fragment`|rtmp, server, application|1 argument|
|`hls_fragment_naming`|rtmp, server, application|1 argument|
|`hls_fragment_naming_granularity`|rtmp, server, application|1 argument|
|`hls_fragment_slicing`|rtmp, server, application|1 argument|
|`hls_fragments_per_key`|rtmp, server, application|1 argument|
|`hls_key_path`|rtmp, server, application|1 argument|
|`hls_key_url`|rtmp, server, application|1 argument|
|`hls_keys`|rtmp, server, application|1 argument|
|`hls_max_audio_delay`|rtmp, server, application|1 argument|
|`hls_max_fragment`|rtmp, server, application|1 argument|
|`hls_muxdelay`|rtmp, server, application|1 argument|
|`hls_nested`|rtmp, server, application|1 argument|
|`hls_path`|rtmp, server, application|1 argument|
|`hls_playlist_length`|rtmp, server, application|1 argument|
|`hls_sync`|rtmp, server, application|1 argument|
|`hls_type`|rtmp, server, application|1 argument|
|`hls_variant`|rtmp, server, application|1 or more arguments|

### MPEG-DASH

|Directive|Context|Takes|
|---|---|---|
|`dash`|rtmp, server, application|1 argument|
|`dash_cleanup`|rtmp, server, application|1 argument|
|`dash_fragment`|rtmp, server, application|1 argument|
|`dash_nested`|rtmp, server, application|1 argument|
|`dash_path`|rtmp, server, application|1 argument|
|`dash_playlist_length`|rtmp, server, application|1 argument|

### Relaying: pull and push

|Directive|Context|Takes|
|---|---|---|
|`pull`|application|1 or more arguments|
|`pull_reconnect`|rtmp, server, application|1 argument|
|`push`|application|1 or more arguments|
|`push_reconnect`|rtmp, server, application|1 argument|
|`relay_buffer`|rtmp, server|1 argument|
|`rtmp_auto_push`|main|1 argument|
|`rtmp_auto_push_reconnect`|main|1 argument|
|`rtmp_socket_dir`|main|1 argument|
|`session_relay`|rtmp, server, application|1 argument|

### Callbacks to an HTTP backend

|Directive|Context|Takes|
|---|---|---|
|`netcall_buffer`|rtmp, server|1 argument|
|`netcall_timeout`|rtmp, server|1 argument|
|`notify_method`|rtmp, server, application|1 argument|
|`notify_relay_redirect`|rtmp, server, application|1 argument|
|`notify_update_strict`|rtmp, server, application|1 argument|
|`notify_update_timeout`|rtmp, server, application|1 argument|
|`on_connect`|rtmp, server|1 argument|
|`on_disconnect`|rtmp, server|1 argument|
|`on_done`|rtmp, server, application|1 argument|
|`on_play`|rtmp, server, application|1 argument|
|`on_play_done`|rtmp, server, application|1 argument|
|`on_publish`|rtmp, server, application|1 argument|
|`on_publish_done`|rtmp, server, application|1 argument|
|`on_record_done`|rtmp, server, application, recorder|1 argument|
|`on_update`|rtmp, server, application|1 argument|

### Running an external program

|Directive|Context|Takes|
|---|---|---|
|`exec`|rtmp, server, application|1 or more arguments|
|`exec_kill_signal`|rtmp, server, application|1 argument|
|`exec_options`|rtmp, server, application|1 argument|
|`exec_play`|rtmp, server, application|1 or more arguments|
|`exec_play_done`|rtmp, server, application|1 or more arguments|
|`exec_publish`|rtmp, server, application|1 or more arguments|
|`exec_publish_done`|rtmp, server, application|1 or more arguments|
|`exec_pull`|rtmp, server, application|1 or more arguments|
|`exec_push`|rtmp, server, application|1 or more arguments|
|`exec_record_done`|rtmp, server, application, recorder|1 or more arguments|
|`exec_static`|rtmp, server, application|1 or more arguments|
|`respawn`|rtmp, server, application|1 argument|
|`respawn_timeout`|rtmp, server, application|1 argument|

### Playing files

|Directive|Context|Takes|
|---|---|---|
|`play`|rtmp, server, application|1 or more arguments|
|`play_local_path`|rtmp, server, application|1 argument|
|`play_temp_path`|rtmp, server, application|1 argument|

### Limits, access and logging

|Directive|Context|Takes|
|---|---|---|
|`access_log`|rtmp, server, application|1 or 2 arguments|
|`allow`|rtmp, server, application|1 or 2 arguments|
|`deny`|rtmp, server, application|1 or 2 arguments|
|`log_format`|rtmp, server, application|2 or more arguments|
|`max_connections`|rtmp, server, application|1 argument|

### The HTTP endpoints

|Directive|Context|Takes|
|---|---|---|
|`rtmp_control`|http, server, location|1 or more arguments|
|`rtmp_stat`|http, server, location|1 or more arguments|
|`rtmp_stat_stylesheet`|http, server, location|1 argument|

## Testing

```sh
ci/build.sh 1.30.6 /tmp/nginx-test
TEST_NGINX_BINARY=/tmp/nginx-test/sbin/nginx prove -r t/
ci/hls.sh /tmp/nginx-test/sbin/nginx
ci/reload.sh /tmp/nginx-test/sbin/nginx
ci/version.sh
```

No RTMP client connects in the suite: that needs a handshake and a media
stream, which belongs in a test of its own. What it asks is what nginx
accepts in `rtmp{}`, and that `rtmp_stat` serves what the module knows.
The reload gate reads `rtmp_stat` after every reload, so it notices a
module that came back without its state.

`ci/hls.sh` is the gate for the inherited-path case above. It starts nginx
with `hls_path` and `dash_path` set one level up and asserts that nginx
created both directories: registering the path is what schedules the
cleanup, and creating the directory is the only sign of it from outside.
The suite can only see that the warning stays away, which a wrong merge
order keeps true while the cleanup is gone again.

`ci/version.sh` holds the version in `src/ngx_rtmp_version.h` against
`CHANGELOG.md`. The statistics page publishes that value, and it had been
four releases stale.

## License

BSD 2-Clause. See `LICENSE`.
