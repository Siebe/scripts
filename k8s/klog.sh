#!/usr/bin/env bash

usage() {
  echo 'KLog - Easily log multiple pods in your Kubernetes cluster'
  echo 'Requires kubectl, jq and "kget.sh" in the $SCRIPT_DIR or same directory. Usage:'
  echo  -n './klog.sh [-hlv] -c [-c KUBECTL_CONTEXT] [-o CONTAINER] [-t TAIL_LINES ]'
  echo ' [-s SCAN_INTERVAL] [-m MAXIMUM_PODS] [KUBECTL_NAMESPACE] [INPUT_PATTERN]'
  echo 'KUBECTL_NAMESPACE = k8s namespace to use, default is "default"'
  echo 'INPUT_PATTERN = regex pattern to filter pod names or labels, case insensitive'
  echo '-c KUBECTL_CONTEXT = k8s context to use, default is current context'
  echo '-o CONTAINER = specific name of container to log in pods, default is all containers'
  echo '-t TAIL_LINES = number of log lines to output initially per pod, default is -1 (all)'
  echo -n '-s SCAN_INTERVAL = number of seconds to scan for new/restarted pods in a loop. '
  echo '0 means scan only once, default is to loop every 30 seconds'
  echo '-m MAXIMUM_PODS = maximum number of processes spawned to log pods, default is 10'
  echo '-l = filter on all label values instead of pod name, case insensitive'
  echo '-v = verbose mode'
  echo '-h = display usage and examples'
}

examples() {
  echo ''
  echo 'Examples:'
  echo 'Log no more than 20 pods from "databases" namespace:'
  echo './klog.sh -m 20 databases'
  echo ''
  echo 'Log no more than 10 pods from "databases" with names matching "mongodb", verbose mode:'
  echo './klog.sh -v databases mongodb'
  echo ''
  echo 'Log pods from "workers" namespaces, with label value matching "nginx", select "webserver" container:'
  echo './klog.sh -l -o webserver workers nginx'
  echo ''
  echo 'Log pods from "workers" namespace, "my-cluster" context and scan for new pods every 2 minutes:'
  echo './klog.sh -c my-cluster -s 120 workers nginx'
  echo ''
  echo 'Log pods from "monitoring" namespace, pods names start with "server", don''t scan for new pods'
  echo './klog.sh -s 0 monitoring "\bserver"'
}

## Variables ##

KUBECTL_CONTEXT=${KUBECTL_CONTEXT-''}
KUBECTL_NAMESPACE=${KUBECTL_NAMESPACE-'default'}
kget_arguments=''
kget_command=''
log_arguments=''
log_command=''
input_pattern=''
container=''
tail='-1'
scan_interval='30'
process_was_running=1
maximum_pods=10
number_regex='^[0-9]+$'
scanning_in_progress=0

log_pids=()
log_pods=()
log_index=0

#https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
[ -n "$SCRIPT_DIR" ] && kget_executable="${SCRIPT_DIR}/k8s/kget.sh" || \
  kget_executable="$(dirname -- "$( readlink -f -- "$0"; )")/kget.sh"

## Functions ##

array_find() {
  find_value="$1"
  shift
  array=("$@")
  for index in "${!array[@]}"; do
     if [ "${array[$index]}" = "${find_value}" ]; then
         echo "${index}";
         return
     fi
  done
  echo "-1"
}

array_remove_index() {
  remove_index="$1"
  shift
  array=("$@")
  output=()
  for index in "${!array[@]}"; do
    [ "$index" != "${remove_index}" ] && output+=("${array[$index]}")
  done
  echo "${output[@]}"
}

log_template_json() {
  while read log_logline; do
    received_at=$(date --iso-8601=seconds)
    log_line_escaped="${log_logline//\\/\\\\}"
    log_line_escaped="${log_line_escaped//\"/\\\"}"
    echo "{\"name\":\"${1}\",\"received_at\": \"${received_at}\",\"log\":\"${log_line_escaped}\"}"
  done
}

scan_pods_and_log() {
  if [ $scanning_in_progress -eq 1 ]; then
    [ -n "$verbose" ] && echo "Scan already in progress, aborting"
    return 0
  fi
  scanning_in_progress=1
  [ -n "$verbose" ] && echo "Scan pods with command: ${kget_command}"
  podlist=( $(bash -c "$kget_command") )

  for pod in "${podlist[@]}"; do
    [ -n "$verbose" ] && echo "Checking log process for ${pod}"
    existing_index='-1'
    existing_index=$(array_find "$pod" "${log_pods[@]}")
    if [ "$existing_index" -gt -1 ]; then
      pid=${log_pids[${existing_index}]}
      if ps -p "$pid" > /dev/null; then
        [ -n "$verbose" ] && echo "Already logging ${pod}, pid: ${pid}"
        continue;
      fi
      [ -n "$verbose" ] && echo "Processs ${pid} for ${pod} stopped, trying again."
      log_pids=( $(array_remove_index "$existing_index" "${log_pids[@]}") )
      log_pods=( $(array_remove_index "$existing_index" "${log_pods[@]}") )
    fi
    if [ "${#log_pods[@]}" -ge "$maximum_pods" ]; then
      [ -n "$verbose" ] && echo "Already logging maximum amount of pods"
      continue;
    fi
    log_command="kubectl logs --max-log-requests 10 -f${log_arguments} $pod"
    [ -n "$verbose" ] && echo "Spawning log process with command: ${log_command}"
    bash -c "$log_command" | log_template_json "$pod" &
    pid=$!
    log_pids[${log_index}]=$pid
    log_pods[${log_index}]=$pod
    log_index=$((log_index+1))
    [ -n "$verbose" ] && echo "Process ${pid} for ${pod} started"
  done;
  scanning_in_progress=0
}

start_scan_loop() {
  while true; do
    [ -n "$verbose" ] && echo "Scan loop: waiting ${scan_interval} seconds"
    sleep "$scan_interval"
    [ -n "$verbose" ] && echo "Scan loop: scan for pods again"
    scan_pods_and_log
  done
}

## Argument processing ##

while getopts "hc:o:t:s:m:lv" options
do
	case $options in
		h ) usage; examples; exit 0;;
    c ) KUBECTL_CONTEXT=${OPTARG};;
    o ) container=${OPTARG};;
    t ) tail=${OPTARG};;
    s ) scan_interval=${OPTARG};;
    m ) maximum_pods=${OPTARG};;
    l ) label_pattern=1;; #lowercase
    v ) verbose=1;;
    ? ) echo 'Error: invalid option' >&2; usage; exit 1;;
	esac
done
shift $(($OPTIND - 1))

if [ $# -ge 1 ] ; then
  #one argument found, namespace to lowercase
  KUBECTL_NAMESPACE="${1,,}"
fi
if [ $# -ge 2 ] ; then
  #two arguments found, pattern to lowercase
  input_pattern="${2,,}"
fi

[[ $scan_interval =~ $number_regex ]] || { echo "error: SCAN_INTERVAL is not a number" >&2; exit 1; }
[[ $maximum_pods =~ $number_regex ]] || { echo "error: MAXIMUM_PODS is not a number" >&2; exit 1; }

if [ -n "$verbose" ]; then
  [ "$KUBECTL_CONTEXT" != '' ] &&  echo "Alternative k8s context: ${KUBECTL_CONTEXT}" ||\
    echo "Current K8s context: $(kubectl config current-context)"
  echo "K8s namespace: ${KUBECTL_NAMESPACE}";
  echo "Pattern to search for: ${input_pattern}"
  [ -n "$label_pattern" ] && echo "Search in label values of pods";
  [ "$container" != '' ] && echo "Log container: ${container}" || echo "Log all containers"
fi

[ "$KUBECTL_CONTEXT" != '' ] && kget_arguments="${kget_arguments} -c ${KUBECTL_CONTEXT}" && \
  log_arguments="${log_arguments} --context ${KUBECTL_CONTEXT}"

kget_arguments="${kget_arguments} -n ${KUBECTL_NAMESPACE}"
log_arguments="${log_arguments} -n ${KUBECTL_NAMESPACE}"

[ -n "$label_pattern" ] && kget_arguments="${kget_arguments} -l" && \\

[ "$container" != '' ] && log_arguments="${log_arguments} -c ${container}" || \
  log_arguments="${log_arguments} --all-containers"
log_arguments="${log_arguments} --tail ${tail}"

kget_command="${kget_executable} -k pod -j${kget_arguments} \"${input_pattern}\" | \
jq -r 'select(.podStatus == \"Running\") | .name' | sed 's/\\n/ /'"

## Scan and Log Processing ##

[ -n "$verbose" ] && echo "Starting initial Scan for pods";
scan_pods_and_log
[ "${#log_pods[@]}" -eq 0 ] && { echo "No pods found in ${KUBECTL_NAMESPACE} namespace" >&2; exit 1; }

[ "$scan_interval" -ge 1 ] && { [ -n "$verbose" ] && echo "Starting Scan loop"; start_scan_loop & }

#https://stackoverflow.com/questions/360201/how-do-i-kill-background-processes-jobs-when-my-shell-script-exits
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

## Keep alive  ##

while [ $process_was_running -eq 1 ]; do
  # wait for all pids
  process_was_running=0
  for pid in ${log_pids[*]}; do
    { [ "$pid" == '' ] || [ -z "$pid" ]; } && continue
    if ps -p $pid > /dev/null; then
      [ -n "$verbose" ] && echo "Logging process ${pid} is running, awaiting"
      process_was_running=1
    fi
    wait $pid
          [ -n "$verbose" ] && echo "Process ${pid} already stopped"

  done
  if [ "$scan_interval" -ge 1 ] && [ $process_was_running -eq 1 ]; then
    [ -n "$verbose" ] && echo "All logging processes stopped, scanning again in ${scan_interval} seconds";
    sleep "$scan_interval"
    scan_pods_and_log
  fi
done

[ -n "$verbose" ] && echo "Exiting normally, all log processes ended"
exit 0
