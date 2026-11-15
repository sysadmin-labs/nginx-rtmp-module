# Changelog

## Unreleased

First release from this repository. It continues Roman Arutyunyan's
module, whose history is intact here; his repository has had no commit
since December 2024.

### Fixed

- **An inherited `hls_path` or `dash_path` left the cleanup unregistered.**
  Both modules read `conf->path` to register their cleanup handler and
  merged the inherited value after that, so for an application inheriting
  the path from `rtmp{}` or `server{}` it was still empty and no cleanup
  was registered — while `hls_cleanup` and `dash_cleanup` are on by
  default. Fragments were then kept forever with nothing logged.
  Registering the path is also what makes nginx create the directory at
  startup, which is how the difference is visible from outside, and that
  is what the gate in `t/00-directives.t` asks for.

### Changed

- `hls on` or `dash on` without any path now logs a warning instead of
  writing nothing in silence. Deliberately a warning and not an error, so
  a configuration that starts today still starts.
- Sources moved to `src/`, with `hls/` and `dash/` below it.
- `config` uses the `auto/module` form only; the pre-1.9.11 branch it
  carried alongside could not build a loadable module.

### Added

- Continuous integration against nginx 1.28, 1.30 and 1.31, statically and
  dynamically, with sanitizers, valgrind, CodeQL, a reload gate and a
  FreeBSD run.
- `t/00-directives.t` for what `rtmp{}` accepts, what `rtmp_stat` and
  `rtmp_control` answer, and the inherited-path case above.
