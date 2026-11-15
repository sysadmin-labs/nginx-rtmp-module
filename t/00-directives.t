# The rtmp{} block parses and the two HTTP endpoints answer.
#
# No RTMP client connects here: that needs a handshake and a media stream,
# which belongs in a test of its own.  What is asked here is what nginx
# accepts in rtmp{} -- the part that breaks when the module meets a newer
# nginx -- and that rtmp_stat and rtmp_control serve what the module
# itself knows.

use Test::Nginx::Socket 'no_plan';

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: a live application, and the statistics list it
--- main_config
    rtmp {
        server {
            listen 127.0.0.1:1935;
            application testapp {
                live on;
            }
        }
    }
--- config
    location /stat { rtmp_stat all; }
--- request
GET /stat
--- response_body_like: <name>testapp</name>
--- error_code: 200



=== TEST 2: the statistics carry the module's version
--- main_config
    rtmp {
        server {
            listen 127.0.0.1:1935;
            application a { live on; }
        }
    }
--- config
    location /stat { rtmp_stat all; }
--- request
GET /stat
--- response_body_like: <nginx_rtmp_version>



=== TEST 3: rtmp_control answers, and does not know an invented command
--- main_config
    rtmp {
        server {
            listen 127.0.0.1:1935;
            application a { live on; }
        }
    }
--- config
    location /control { rtmp_control all; }
--- request
GET /control/nosuchcommand
--- error_code: 404



=== TEST 4: recording, relay, notify and exec parse
--- main_config
    rtmp {
        server {
            listen 127.0.0.1:1935;
            chunk_size 4096;
            ping 30s;
            ping_timeout 10s;

            application rec {
                live on;
                record all;
                record_path /tmp/rtmp-test-rec;
                record_suffix -%d-%b-%y-%T.flv;
                record_unique on;
                record_max_size 64M;
            }

            application pull {
                live on;
                pull rtmp://127.0.0.1:1936/src/stream;
            }

            application push {
                live on;
                push rtmp://127.0.0.1:1936/dst;
            }

            application cb {
                live on;
                on_publish http://127.0.0.1:8080/on_publish;
                on_play    http://127.0.0.1:8080/on_play;
                notify_method get;
            }

            max_streams 32;
            max_message 1M;

            application lim {
                live on;
                max_connections 10;
            }
        }
    }
--- config
    location /t { return 200 "ok\n"; }
--- request
GET /t
--- response_body
ok



=== TEST 5: HLS and DASH parse
--- main_config
    rtmp {
        server {
            listen 127.0.0.1:1935;

            application hlsapp {
                live on;
                hls on;
                hls_path /tmp/rtmp-test-hls;
                hls_fragment 5s;
                hls_playlist_length 30s;
                hls_nested on;
                hls_cleanup on;
            }

            application dashapp {
                live on;
                dash on;
                dash_path /tmp/rtmp-test-dash;
                dash_fragment 5s;
                dash_playlist_length 30s;
                dash_cleanup on;
            }
        }
    }
--- config
    location /t { return 200 "ok\n"; }
--- request
GET /t
--- response_body
ok



=== TEST 6: access control parses in the right order
--- main_config
    rtmp {
        server {
            listen 127.0.0.1:1935;
            application a {
                live on;
                allow publish 127.0.0.1;
                deny publish all;
                allow play all;
            }
        }
    }
--- config
    location /t { return 200 "ok\n"; }
--- request
GET /t
--- response_body
ok



=== TEST 7: an application without a server block is refused
--- main_config
    rtmp {
        application stray {
            live on;
        }
    }
--- config
    location /t { return 200 "ok\n"; }
--- must_die



=== TEST 8: hls without a path is said out loud, not swallowed
--- main_config
    rtmp {
        server {
            listen 127.0.0.1:1935;
            application a {
                live on;
                hls on;
            }
        }
    }
--- config
    location /t { return 200 "ok\n"; }
--- request
GET /t
--- response_body
ok
--- error_log
hls is on but no hls_path is set



=== TEST 9: an hls_path from the server block reaches the application
--- main_config
    rtmp {
        server {
            listen 127.0.0.1:1935;
            hls_path /tmp/rtmp-test-inherited;
            application a {
                live on;
                hls on;
            }
        }
    }
--- config
    location /t { return 200 "ok\n"; }
--- request
GET /t
--- response_body
ok
--- no_error_log
hls is on but no hls_path is set
