#!/usr/bin/env bash

usage () {
  echo 'Use rsync to synchronise files between a kubernetes pod and local filesystem.'
  echo 'Requires rsync on both local machine and pod and kubectl on the local machine. Usage:'
	echo -n ' ./ksync.sh [-hvdr] [-c KUBECTL_CONTEXT] [-n KUBECTL_NAMESPACE] [-o KUBECTL_CONTAINER]'
	echo ' [-x RSYNC_EXCLUDE] {LOCAL_SOURCE|REMOTE_SOURCE} {REMOTE_DESTINATION|LOCAL_DESTINATION}'
	echo 'LOCAL_SOURCE = source directory on local machine, to be used with REMOTE_DESTINATION'
	echo 'REMOTE_SOURCE = name of pod and remote source directory, separated by a colon, eg. my-pod:/home/source'
	echo 'LOCAL_DESTINATION = destination directory on local machine, to be used with REMOTE_SOURCE'
  echo -n 'REMOTE_DESTINATION = name of pod and remote destination directory, '
  echo 'separated by a colon, eg. my-pod:/home/destination'
  echo '-c KUBECTL_CONTEXT = k8s context to use, default is current context'
  echo '-n KUBECTL_NAMESPACE = k8s namespace to use, default is "default"'
  echo '-o KUBECTL_CONTAINER = containername of k8s pod, default is primary container'
  echo '-x RSYNC_EXCLUDE = exclude pattern to be parsed to rsync, default none'
  echo '-r = treat name of pod for remote as regular expression pattern and search for pod'
	echo '-v = verbose mode'
	echo '-d = dry run'
	echo '-h = display usage and examples'
}

examples () {
  echo ''
  echo 'Examples:'
  echo 'Synchronise directory towards a pod named "worker" in default namespace, verbose mode:'
  echo './ksync.sh -v /home/user/sourcedir worker:/etc/destdir'
  echo ''
  echo 'Synchronise directory from a pod named "backup" in "test" namespace:'
  echo './ksync.sh -n test  backup:/var/sourcedir /home/user/destdir'
  echo ''
  echo 'Synchronise directory to a pod matching /service$/ exclude node_modules directory:'
  echo './ksync.sh -rx node_nodules /home/user/sourcecode service$:/var/myservice '
  echo
  echo 'Synchronise directory from a pod named "db" via a container called "side-car", context called "my-cluster":'
  echo './ksync.sh -o side-car -c my-cluster db:/var/somedbfiles /var/backup/somedbfiles'
}

kubectl_flags=''
rsync_flags=''

KUBECTL_CONTEXT=${KUBECTL_CONTEXT-''}
KUBECTL_NAMESPACE=${KUBECTL_NAMESPACE-'default'}

while getopts "hvdrc:n:o:x:" options
do
	case $options in
		h ) usage; examples; exit 0;;
    c ) KUBECTL_CONTEXT=${OPTARG};;
    n ) KUBECTL_NAMESPACE=${OPTARG};;
    o ) KUBECTL_CONTAINER=${OPTARG};;
    x ) rsync_exclude=${OPTARG};;
    r ) pod_regex=1;;
    v ) verbose=1;;
    d ) dry_run=1;;
    ? ) >&2 echo 'Error: invalid option' >&2; usage; exit 1;;
	esac
done
shift $(($OPTIND - 1))

[ $# -lt 2 ] && { >&2 echo "Missing source and destination arguments"; usage; exit 1; }

if [[ "$1" =~ [-a-z0-9]+\:.+ ]]; then
  direction_outgoing=0
  remote_pod_input=${1%%:*}
  remote_directory=${1#*:}
  local_directory="$2"
elif [[ "$2" =~ [-a-z0-9]+\:.+ ]]; then
  direction_outgoing=1
  remote_pod_input=${2%%:*}
  remote_directory=${2#*:}
  local_directory="$1"
else
  >&2 echo "One of the arguments has to be remote"; usage; exit 1
fi

if [ -n "$verbose" ]; then
  echo -n "Will copy files from "
  [ "$direction_outgoing" -eq 1 ] && echo "local to remote" || echo "remote to local"
  echo "Local directory: ${local_directory}"
  echo "Remote directory: ${remote_directory}"
  echo -n "Kubernetes context: "
  [ "$KUBECTL_CONTEXT" != '' ] && echo "$KUBECTL_CONTEXT" || kubectl config current-context
  echo -n "Kubernetes namespace: "
  [ "$KUBECTL_NAMESPACE" != '' ] && echo "$KUBECTL_NAMESPACE" || echo default
  [ "$rsync_exclude" != '' ] && echo "Exclude from rsync: ${rsync_exclude}"
  echo "Verbose mode: true"
  echo -n "Dry run mode: "
  [ -n "$dry_run" ] && echo "true" || echo "false"
  [ -n "$pod_regex" ] && echo -n "Will search for pod with pattern: " || echo -n "Will copy to pod: "
  echo "$remote_pod_input"
fi

[ "$KUBECTL_CONTEXT" != '' ] && kubectl_flags="${kubectl_flags} --context ${KUBECTL_CONTEXT}"
 [ "$KUBECTL_NAMESPACE" != 'default' ] || [ "$KUBECTL_NAMESPACE" != '' ] && \
  kubectl_flags="${kubectl_flags} -n ${KUBECTL_NAMESPACE}"

[ -n "$verbose" ] && rsync_flags="${rsync_flags} -v"
[ "$rsync_exclude" != '' ] && rsync_flags="${rsync_flags} --exclude ${rsync_exclude}"

if [ -n "$pod_regex" ]; then
  pod_find_command="kubectl get${kubectl_flags} --no-headers -o custom-columns=\":metadata.name\"  pods 2>&1 | \
grep -P '${remote_pod_input}' | head  -n1"
  [ -n "$pod_regex" ] && echo "Command to find pod: ${pod_find_command}"
  remote_pod=$(bash -c "$pod_find_command")
else
  remote_pod=$remote_pod_input
fi

[ "$remote_pod" = '' ] && { echo "Pod with pattern \"${remote_pod_input}\" not found!"; usage; exit 1; }

[ "$KUBECTL_CONTAINER" != '' ] && kubectl_flags="$kubectl_flags -c $KUBECTL_CONTAINER"

if [ -n "$verbose" ]; then
  [ -n "$pod_regex" ] && echo "Found pod: ${remote_pod}"
  [ "$KUBECTL_CONTAINER" != '' ] && echo "Will connect with container: ${KUBECTL_CONTAINER}" || \
    echo "Will connect with default container"
fi

command="rsync${rsync_flags} --archive --blocking-io \
--rsh=\"kubectl${kubectl_flags} exec -i ${remote_pod} --\""

if [ "$direction_outgoing" -eq 0 ]; then
  command="${command} rsync:${remote_directory}/ ${local_directory}"
else
  command="${command} ${local_directory}/ rsync:${remote_directory}"
fi

[ -n "$dry_run" ] || [ -n "$verbose" ] && echo "Full command: ${command}"
if [ -n "$dry_run" ]; then
  echo "Dry run, testing kubectl connection"
  bach -c "kubectl${kubectl_flags} exec -i ${remote_pod} --"
fi

[ -n "$verbose" ] && echo "============= Running"
#bash -c "$command"
[ -n "$verbose" ] && echo "============= ktnxbye"

# rsync -v --archive --blocking-io --rsync-path=${REMOTE_SOURCE_DIR} \
# --rsh="kubectl --context=${KUBECTL_CONTEXT} -n${KUBECTL_NAMESPACE} exec -i ${uploadpod} --" \
# --exclude "${RSYNC_EXCLUDE}" \
# rsync:${REMOTE_SOURCE_DIR}/ ${LOCAL_DEST_DIR}
