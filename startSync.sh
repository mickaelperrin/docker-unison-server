#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

LOCAL=true
CONTAINER_NAME=
SERVER=
SERVER_IP=
SSH_CMD=eval

parseArgs() {
  while test $# -gt 0; do
    case "$1" in
      --server*)
        LOCAL=false
        SERVER="$(echo $1 | sed -e 's/^[^=]*=//g')"
        SSH_CMD="ssh $1"
        shift
        ;;
      --server-ip*)
        SERVER_IP="$(echo $1 | sed -e 's/^[^=]*=//g')"
        shift
        ;;
      --container*)
        CONTAINER_NAME="$(echo $1 | sed -e 's/^[^=]*=//g')"
        shift
        ;;
      *)
        echo "$1"
        break
        ;;
    esac
done

if [ -z "$SERVER" ]; then
  SERVER_IP=127.0.0.1
fi

}

checks() {
  if [ -z "$CONTAINER_NAME" ]; then
    echo "Missing unison container name. Use argument: --container CONTAINER_NAME. Aborting..."
    exit 1
  fi

  # Check that we can SSH in remote server
  if ! $(${SSH_CMD} "true"); then
    echo "Can't SSH to remote server. Aborting..."
    exit 1
  fi

  # Check that unison container is running
  IS_CONTAINER_RUNNING=$(${SSH_CMD} "docker inspect -f {{.State.Running}} $CONTAINER_NAME")
  if [ "$IS_CONTAINER_RUNNING" != 'true' ]; then
    echo "Container $CONTAINER_NAME is not running. Exiting"
    exit 1
  fi

  # Get remote unison port
  REMOTE_PORT=$(${SSH_CMD} "docker inspect --format='{{(index (index .NetworkSettings.Ports \"5000/tcp\") 0).HostPort}}' $CONTAINER_NAME")
  echo "Unison is running on port ${REMOTE_PORT} on remote server"

  UNISON_ARGS=$(${SSH_CMD} "docker exec $CONTAINER_NAME bash -c 'echo \$UNISON_ARGS'")
}

start() {
  UNISON_COMMAND="unison -auto -batch -repeat watch ${EXCLUDE_CONFIG//\"/} ${SYNC_DIR:-$(pwd)} socket://${SERVER_IP:-$SERVER}:${REMOTE_PORT}"
  echo
  echo "Running unison with the following command:"
  echo "$UNISON_COMMAND"
  eval $UNISON_COMMAND
}

parseArgs "$@"
checks
start