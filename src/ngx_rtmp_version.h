
/*
 * Copyright (C) Roman Arutyunyan
 */


#ifndef _NGX_RTMP_VERSION_H_INCLUDED_
#define _NGX_RTMP_VERSION_H_INCLUDED_


/*
 * Kept in step with CHANGELOG.md by ci/version.sh, which the lint
 * workflow runs.  The value reaches the outside: ngx_rtmp_stat_module
 * puts it into the statistics page as <nginx_rtmp_version>, and stat.xsl
 * renders it, so a stale one is published rather than merely wrong.
 */
#define nginx_rtmp_version  1003001
#define NGINX_RTMP_VERSION  "1.3.1"


#endif /* _NGX_RTMP_VERSION_H_INCLUDED_ */
