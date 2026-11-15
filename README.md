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

## Where this comes from

Roman Arutyunyan's module, continued here with its history intact. His
repository has had no commit since December 2024, carries over a thousand
open issues, and the FreeBSD port builds from it.

**Fixed here:** an `hls_path` or `dash_path` given in `rtmp{}` or
`server{}` never reached an application that inherited it. Both modules
read the path to register their cleanup handler and merged the inherited
value *after* that, so for an inheriting application the path was still
empty and no cleanup was registered at all — while `hls_cleanup` and
`dash_cleanup` are on by default. Fragments were then kept forever and the
filesystem filled up with nothing logged. Registering the path is also
what makes nginx create the directory at startup, which is how the
difference is visible from outside: `t/00-directives.t` asks for it.

`hls on` without any path now says so as a warning instead of writing
nothing in silence. It is a warning and not an error on purpose, so a
configuration that starts today still starts.

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

There are far too many to repeat here and they are documented in `doc/`,
which is the upstream wiki as it stood. The shape of it: `rtmp{}` holds
`server{}` blocks, a server holds `application{}` blocks, and an
application is where `live`, `record`, `pull`, `push`, `exec`, `hls` and
`dash` go. `rtmp_stat` and `rtmp_control` are HTTP locations.

## Testing

```sh
ci/build.sh 1.30.6 /tmp/nginx-test
TEST_NGINX_BINARY=/tmp/nginx-test/sbin/nginx prove -r t/
ci/reload.sh /tmp/nginx-test/sbin/nginx
```

No RTMP client connects in the suite: that needs a handshake and a media
stream, which belongs in a test of its own. What it asks is what nginx
accepts in `rtmp{}`, that `rtmp_stat` serves what the module knows, and
the inherited-path case above. The reload gate reads `rtmp_stat` after
every reload, so it notices a module that came back without its state.

## License

BSD 2-Clause. See `LICENSE`.
