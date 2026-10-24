#!/bin/sh
# zmod_dualweb: serve the web interface Zmod is not using on port 81.
#
#   dualweb.sh start    (re)start the port 81 server
#   dualweb.sh stop     stop it
#   dualweb.sh status   show which interface is on which port
#
# Zmod serves the interface named in mod_data/web.conf on port 80. This runs a
# second nginx on port 81 with the other one, built from Zmod's own nginx
# template so the Moonraker, webcam and screen proxies match port 80. Zmod's
# WEB macro flips web.conf, so after WEB the two interfaces swap ports.

unset LD_PRELOAD

PLUGIN=/opt/config/mod_data/plugins/zmod_dualweb

# Zmod's nginx and web roots live inside its chroot; run there like S70httpd.
if [ ! -f /ZMOD ] && [ -z "$DUALWEB_CHROOT" ]; then
    . /usr/data/zmod/zmod/.shell/0.sh
    exec chroot "$MOD" /usr/bin/env DUALWEB_CHROOT=1 /bin/sh "$PLUGIN/dualweb.sh" "$@"
fi

PORT=81
ZNGINX=/usr/data/zmod/zmod/.shell/root/nginx
DIR=/root/nginx/dualweb
CONF=$DIR/nginx.conf
PID_FILE=$DIR/nginx.pid
# Zmod's S70httpd stops its server with "killall nginx". A copy of the binary
# under another name keeps port 81 up through that (busybox killall also
# matches the target of /proc/PID/exe, so a symlink is not enough).
BIN=$DIR/zdualweb
LOG=/opt/config/mod_data/log/zmod_dualweb.log

CLIENT=fluidd
[ -f /opt/config/mod_data/web.conf ] && . /opt/config/mod_data/web.conf
case "$CLIENT" in
    mainsail) OTHER=fluidd ;;
    *) CLIENT=fluidd; OTHER=mainsail ;;
esac

running() {
    pid=$(cat "$PID_FILE" 2>/dev/null) && kill -0 "$pid" 2>/dev/null
}

stop() {
    if running; then
        kill "$pid"
        i=0
        while kill -0 "$pid" 2>/dev/null && [ $i -lt 5 ]; do
            sleep 1
            i=$((i + 1))
        done
    fi
    killall zdualweb 2>/dev/null
    rm -f "$PID_FILE"
}

start() {
    if [ ! -x "$ZNGINX/nginx" ] || [ ! -f "$ZNGINX/nginx.conf" ]; then
        echo "dualweb: Zmod's nginx not found in $ZNGINX" >&2
        exit 1
    fi
    if [ ! -f "/root/$OTHER/index.html" ]; then
        echo "dualweb: /root/$OTHER is not installed" >&2
        exit 1
    fi

    stop
    mkdir -p "$DIR/client-body" "$DIR/proxy"
    if [ -L "$BIN" ] || ! cmp -s "$ZNGINX/nginx" "$BIN"; then
        rm -f "$BIN"
        cp "$ZNGINX/nginx" "$BIN" && chmod 755 "$BIN" || exit 1
    fi

    # Keep only the port 80 server block of Zmod's template, move it to our
    # port and web root, and give this instance its own pid and temp files.
    awk '
        /^    server \{/ { buf = $0 "\n"; depth = 1; next }
        depth > 0 {
            buf = buf $0 "\n"
            if ($0 ~ /\{/) depth++
            if ($0 ~ /\}/) depth--
            if (depth == 0 && buf ~ /listen 80;/) printf "%s", buf
            next
        }
        { print }
    ' "$ZNGINX/nginx.conf" | sed \
        -e "s|^pid .*|pid $PID_FILE;|" \
        -e "s|^error_log .*|error_log $DIR/error.log crit;|" \
        -e "s|client_body_temp_path .*|client_body_temp_path $DIR/client-body;|" \
        -e "s|proxy_temp_path .*|proxy_temp_path $DIR/proxy;|" \
        -e "s|listen 80;|listen $PORT;|" \
        -e "s|root /root/[a-z]*/;|root /root/$OTHER/;|" \
        > "$CONF"

    if ! grep -q "listen $PORT;" "$CONF"; then
        echo "dualweb: no port 80 server in Zmod's nginx template" >&2
        exit 1
    fi
    if ! "$BIN" -t -q -c "$CONF" -e "$LOG"; then
        echo "dualweb: nginx rejected $CONF, see $LOG" >&2
        exit 1
    fi
    "$BIN" -c "$CONF" -e "$LOG" || exit 1
    echo "dualweb: $CLIENT on port 80, $OTHER on port $PORT"
}

case "$1" in
    start|restart)
        start
        ;;
    stop)
        stop
        echo "dualweb: port $PORT stopped"
        ;;
    status)
        if running; then
            echo "dualweb: $CLIENT on port 80, $OTHER on port $PORT"
        else
            echo "dualweb: $CLIENT on port 80, port $PORT not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|status}" >&2
        exit 1
        ;;
esac
