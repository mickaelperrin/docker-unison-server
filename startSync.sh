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





exit



LIMIT=1000
INCREASE=10000



# Count number of files in directory to sync
NB_FILES_IN_DIR=$(find ${DIR} -type f | wc -l)

# Increase system limit locally
if [ $(( $(sysctl kern.maxfilesperproc | awk '{ print $2 }') - $NB_FILES_IN_DIR )) -lt $LIMIT ]; then

    # Set max_files_per_proc locally
    if [ -z MAX_FILES_PER_PROC ]; then
      # If no other sync process exists
      export MAX_FILES_PER_PROC=$(( $NB_FILES_IN_DIR + $INCREASE ))
    else
      # If another sync process exists
      # TODO: find a better way to grab other sync processes
      export MAX_FILES_PER_PROC=$(( $MAX_FILES_PER_PROC + $NB_FILES_IN_DIR + $INCREASE ))
    fi
    sudo sysctl -w kern.maxfilesperproc=$MAX_FILES_PER_PROC && echo "kern.maxfilesperproc is now set to $MAX_FILES_PER_PROC" || echo "Error setting kern.maxfilesperproc to $MAX_FILES_PER_PROC"
    sudo sysctl -w kern.maxfiles=$MAX_FILES_PER_PROC && echo "kern.maxfiles is now set to $MAX_FILES_PER_PROC" || echo "Error setting kern.maxfiles to $MAX_FILES_PER_PROC"
else
    echo "kern.maxfilesperproc is currently well configured. Nothing to do"
    echo "kern.maxfiles is currently well configured. Nothing to do"
fi

# Increase system limit in container
#if [ $(${SSH} "cat /proc/sys/fs/inotify/max_user_watches") -lt $(( $NB_FILES_IN_DIR + 10000 )) ]; then
#    ssh ${SERVER_NAME} "echo fs.inotify.max_user_watches=$(( $NB_FILES_IN_DIR + 10000)) | sudo tee -a /etc/sysctl.conf && sudo sysctl -p" \
#    && echo "fs.inotify.max_user_watches is now set to $(( $NB_FILES_IN_DIR + 10000)) in remote container"
#fi

# Run and endless loop to automatically reopen a sync process if the remote container is restarted for example
while true; do

# Restart unison
echo "Restart remote unison server"
${SSH} "docker restart $CONTAINER_NAME"

echo "Waiting 5 seconds"
sleep 5

# Get remote unison port
REMOTE_PORT=$(${SSH} "docker inspect --format='{{(index (index .NetworkSettings.Ports \"5000/tcp\") 0).HostPort}}' $CONTAINER_NAME")
echo "Unison is running on port ${REMOTE_PORT} on remote server"

EXCLUDE_CONFIG=$(${SSH} "docker exec $CONTAINER_NAME bash -c 'echo \$UNISON_EXCLUDES'")
echo "Unison exclude config is set to ${EXCLUDE_CONFIG//\"/}"

# Start the sync process
UNISON_COMMAND="unison -auto -batch -repeat watch ${EXCLUDE_CONFIG//\"/} ${DIR} socket://${SERVER_IP}:${REMOTE_PORT}"
echo "Running unison with the following command: $UNISON_COMMAND"
eval $UNISON_COMMAND

done