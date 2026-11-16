# Changelog

## 1.3.1

First release from this repository, carrying on from upstream's v1.2.2. It
continues Roman Arutyunyan's module, whose history is intact here; his
repository has had no commit since December 2024.

This replaces 1.3.0, whose archive still carried the upstream test tree
the repository had already dropped: compiled Flash objects and a minified
JW Player, none of which the two-clause BSD notice in `LICENSE` covers.

### Fixed

- **An inherited `hls_path` or `dash_path` left the cleanup unregistered.**
  Both modules read `conf->path` to register their cleanup handler and
  merged the inherited value after that, so for an application inheriting
  the path from `rtmp{}` or `server{}` it was still empty and no cleanup
  was registered — while `hls_cleanup` and `dash_cleanup` are on by
  default. Fragments were then kept forever with nothing logged.
  Registering the path is also what makes nginx create the directory at
  startup, which is how the difference is visible from outside, and that
  is what `ci/hls.sh` asks for. The block in `t/00-directives.t` only
  sees that the warning below stays away, which is a weaker statement:
  moving the merge back below the cleanup but above the warning keeps
  that block green and brings the bug back, and `ci/hls.sh` is the gate
  that catches it.

- **Two configuration pools were never freed.** Both
  `ngx_rtmp_live_merge_app_conf` and `ngx_rtmp_core_merge_srv_conf` create
  a pool of their own with `ngx_create_pool`, hanging off no cycle, so
  nginx never knew about it and every reload left the previous one behind:
  4 KB per application and per server for the life of the process, with
  nothing failing and nothing logged. Both now hang a cleanup on
  `cf->pool`, which ties the pool to the cycle that created it. Found by
  the valgrind workflow, which reported them as definitely lost.

### Changed

- `hls on` or `dash on` without any path now logs a warning instead of
  writing nothing in silence. Deliberately a warning and not an error, so
  a configuration that starts today still starts.
- Sources moved to `src/`, with `hls/` and `dash/` below it.
- `config` uses the `auto/module` form only; the pre-1.9.11 branch it
  carried alongside could not build a loadable module.
- The README notes that `so_keepalive` is deprecated in the module's own
  command table, which it did not say.

- **The version this module reported was four releases behind.**
  `src/ngx_rtmp_version.h` said 1.1.4, a file upstream generated and then
  left behind. `ngx_rtmp_stat_module` puts the value into the statistics
  page as `<nginx_rtmp_version>` and `stat.xsl` renders it, so the stale
  number was published rather than merely wrong. `ci/version.sh` now
  holds it against `CHANGELOG.md` in the lint workflow.

### Changed

- `config` says why `USE_OPENSSL=YES` is not optional here: the RTMP
  handshake is HMAC-SHA256, so this module pulls OpenSSL into any build
  that carries it.

### Added

- Continuous integration against nginx 1.28, 1.30 and 1.31, statically and
  dynamically, with sanitizers, valgrind, CodeQL, a reload gate and a
  FreeBSD run.
- `t/00-directives.t` for what `rtmp{}` accepts, what `rtmp_stat` and
  `rtmp_control` answer, and the inherited-path case above.
- `ci/hls.sh`, which starts nginx with an inherited `hls_path` and a
  `dash_path` and asserts that nginx created both directories, so the
  cleanup registration has a gate of its own.
- `ci/version.sh`, run by the lint workflow.
