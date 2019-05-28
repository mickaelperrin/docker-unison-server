#!/usr/bin/env bash
set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

LOCAL=true
CONTAINER_NAME=
SERVER=
SERVER_IP=
SSH_CMD=
SUDO_PASSWORD=
SUDO=true
DEBUG=
UNISON_DEBUG=
NO_RUN=false

parseArgs() {
  while test $# -gt 0; do
    case "$1" in
      --server*)
        LOCAL=false
        SERVER="$(echo $1 | sed -e 's/^[^=]*=//g')"
        SSH_CMD="ssh $SERVER"
        shift
        ;;
      --ip*)
        SERVER_IP="$(echo $1 | sed -e 's/^[^=]*=//g')"
        shift
        ;;
      --container*)
        CONTAINER_NAME="$(echo $1 | sed -e 's/^[^=]*=//g')"
        shift
        ;;
      --no-sudo)
        SUDO=
        shift
        ;;
      --debug)
        DEBUG=true
        UNISON_DEBUG=" -debug all"
        shift
        ;;
      --no-run)
        NO_RUN=true
        shift
        ;;
      *)
        break
        ;;
    esac
done

}

debug() {
  if [ "$DEBUG" = "true" ]; then
    echo
    echo "$*"
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
  if ! checkContainerIsRunning; then
    echo "Container $CONTAINER_NAME is not running. Exiting"
    exit 1
  fi

  # Get remote unison port
  REMOTE_PORT=$(getUnisonPort)
  debug "REMOTE_PORT=${REMOTE_PORT}"

  UNISON_ARGS=$(getUnisonSyncArgs)
  debug "UNISON_ARGS=$UNISON_ARGS"

  if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(resolve $SERVER)
  fi
}


resolve() {
  if [ "$OSTYPE" = "linux-gnu" ]; then
    getent hosts $1 | awk '{ print $1 }'
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    dscacheutil -q host -a name $1 | grep ip_address | awk '{print $2}'
  fi
}

run() {
  if [ ! -z "$SERVER" ]; then
    if [ ! -z "$SUDO" ]; then
      CMDS=$(cat <<CMD
echo "$SUDO_PASSWORD" | sudo -S $@
CMD
)
    else
      CMDS="$*"
    fi
    ssh -o LogLevel=QUIET $SERVER "$CMDS"
  else
    eval "$*"
  fi
}

checkContainerIsRunning() {
  run "docker inspect -f {{.State.Running}} $CONTAINER_NAME > /dev/null"
}

getUnisonPort() {
  run "docker inspect --format='{{(index (index .NetworkSettings.Ports \"5000/tcp\") 0).HostPort}}' $CONTAINER_NAME"
}

getUnisonSyncArgs() {
  run "docker exec $CONTAINER_NAME bash -c 'echo \$UNISON_ARGS'"
}

start() {
  UNISON_COMMAND="/usr/local/bin/unison $UNISON_DEBUG ${UNISON_ARGS//\"/} -auto -batch -repeat watch $(pwd) socket://${SERVER_IP}:${REMOTE_PORT}"
  debug "$UNISON_COMMAND"
  $NO_RUN || eval "$UNISON_COMMAND"
}

askForSudoPassword() {
  if [ ! -z "${SUDO_PASSWORD}" ]; then
    return
  fi

  read -s -p "Sudo password for $SERVER:" SUDO_PASSWORD
  echo
}

parseArgs "$@"
$SUDO && askForSudoPassword
checks
start


