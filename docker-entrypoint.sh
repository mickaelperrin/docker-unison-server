#!/usr/bin/env bash
set -e

if [ "$1" == 'unison' ]; then

    # Increase the maximum watches for inotify for very large repositories to be watched
    # Needs the privilegied docker option
    [ ! -z $MAXIMUM_INOTIFY_WATCHES ] && echo fs.inotify.max_user_watches=$MAXIMUM_INOTIFY_WATCHES | tee -a /etc/sysctl.conf && sysctl -p || true

    # Check if a SH script is available in /docker-entrypoint.d and source it
    for f in /docker-entrypoint.d/*; do
        case "$f" in
            *.sh) echo "$0: running $f"; . "$f" ;;
            *) echo "$0: ignoring $f" ;;
        esac
    done

    if [ -z $SYNC_DIR ]; then
      echo "SYNC_DIR env var is missing. Aborting..."
      exit 1
    fi

    if [ ! -d $SYNC_DIR ]; then
      mkdir -p $SYNC_DIR >> /dev/null 2>&1
      uid=1000
    fi

    [ ! -z "$uid" ] || uid=$(stat -c '%u' $SYNC_DIR)
    if [ "$uid" = "0" ]; then
      unison_user=root
    else
      unison_user=unison
      adduser -u "$uid" -D -h $SYNC_DIR unison
    fi

    # Gracefully stop the process on 'docker stop'
    trap 'kill -TERM $PID' TERM INT

    # Run unison server with unison perms
    cd $SYNC_DIR
    su-exec $unison_user unison -socket 5000 &

    # Wait until the process is stopped
    PID=$!
    wait $PID
    trap - TERM INT
    wait $PID
fi

exec "$@"