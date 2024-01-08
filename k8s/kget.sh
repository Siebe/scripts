#!/usr/bin/env bash

usage() {
  echo 'KGet - Easily find resources in your Kubernetes cluster'
  echo 'Requires kubectl and jq (for JSON output mode). Usage:'
  echo  -n './kget.sh [-hjv] -c [-c KUBECTL_CONTEXT] [-n KUBECTL_NAMESPACE] [-k KIND_RESOURCE]'
  echo ' [-J JSON_EXTRA_MAPPING] [-l LABEL_PATTERN ] [KIND_PATTERN NAME_PATTERN|NAME_PATTERN]'
  echo 'NAME_PATTERN = regex pattern to filter resource names, case insensitive'
  echo 'KIND_PATTERN = regex pattern to filter resource kind, case insensitive'
  echo '-c KUBECTL_CONTEXT = k8s context to use, default is what is current context'
  echo '-n KUBECTL_NAMESPACE = k8s namespace to use, default is all namespaces option'
  echo '-k KIND_RESOURCE = what kind of resource to check, default is "all"'
  echo '-j = JSON output mode (can be slow)'
  echo '-J JSON_EXTRA_MAPPING = JSON output mode with extra mapping, comma separated'
  echo '-l LABEL_PATTERN = filter all label values, case insensitive, JSON output mode'
  echo '-v = verbose mode'
  echo '-h = display usage and examples'
}

examples() {
  echo ''
  echo 'Examples:'
  echo 'kubectl get everything, verbose - ./kget.sh- v'
  echo 'stateful/replica sets, names match "service - ./kget.sh set service'
  echo 'pods with names matching "traefik" - ./kget.sh -k pod traefik'
  echo 'pods, sets and jobs as JSON - ./kget.sh -j "(pod|set|job)" .'
  echo 'pods as JSON with their labels - ./kget.sh -k pod -J "labels:.metadata.labels"'
  echo 'pods from other context - ./kget.sh -c my-other-cluser -k pods'
  echo 'deployments from "default" namespace, names match "core" - ./kget.sh -n default -k deploy core'
  echo 'resources with a label value matching "integration" - ./kget.sh -l integration'
}

name_pattern=''
kind_pattern=''
kind_resource='all'
namespace_argument='--all-namespaces'
context_argument=''
start_pattern='\s+[^\s]*'
jq_filter='.items[] | '
json_extra_mapping=''

own_name=$(basename "$0")

KUBECTL_CONTEXT=${KUBECTL_CONTEXT-''}
KUBECTL_NAMESPACE=${KUBECTL_NAMESPACE-''}

while getopts "hc:n:k:J:l:jv" options
do
	case $options in
		h ) usage; examples; exit 0;;
    c ) KUBECTL_CONTEXT=${OPTARG};;
    n ) KUBECTL_NAMESPACE=${OPTARG};;
    k ) kind_resource="${OPTARG,,}";; #lowercase
    J ) json_extra_mapping="${OPTARG}";;
    l ) label_pattern="${OPTARG,,}";; #lowercase
    j ) json_output=1;;
    v ) verbose=1;;
    ? ) echo 'Error: invalid option' >&2; usage; exit 1;;
	esac
done
shift $(($OPTIND - 1))

if [ $# -eq 1 ] ; then
  #one argument found, pattern for name to lowercase
  name_pattern="${1,,}"
fi
if [ $# -eq 2 ] ; then
  #two arguments found, pattern for name and kind to lowercase
  name_pattern="${2,,}"
  kind_pattern="${1,,}"
fi

[ -n "$verbose" ] && [ "$name_pattern" != '' ] && echo "Checking name for pattern: '${name_pattern}'" &&\
  ( [ "$kind_pattern" != '' ] && [ "$kind_resource" == 'all' ] &&\
    echo "Checking kind for pattern: '${kind_pattern}'" ) ||\
  { [ -n "$verbose" ] && echo "No patterns to filter"; }

[ "$KUBECTL_CONTEXT" != '' ] && context_argument="--context ${KUBECTL_CONTEXT}" && \
  { [ -n "$verbose" ] && echo "Checking alternative context: '${KUBECTL_CONTEXT}'"; } || \
  { [ -n "$verbose" ] && echo "Checking current context: '$(kubectl config current-context)'"; }

[ "$KUBECTL_NAMESPACE" != '' ] && namespace_argument="-n${KUBECTL_NAMESPACE}" && start_pattern='^[^\s]*' &&\
  { [ -n "$verbose" ] && echo "Checking namespace: '${KUBECTL_NAMESPACE}'"; } ||\
  { [ -n "$verbose" ] && echo "Checking all namespaces"; }

#Force JSON output for JSON extra mapping
[ "$json_extra_mapping" != '' ] && json_output=1 &&\
  [ -n "$verbose" ] && echo "Extra JSON Mapping: ${json_extra_mapping}"

#Force JSON output for label pattern
[ "$label_pattern" != '' ] && json_output=1 &&\
  [ -n "$verbose" ] && echo "Checking label for pattern: ${label_pattern}"

if [ -z $json_output ]; then
  #Assemble grep pattern for regular output
  grep_filter="${start_pattern}${name_pattern}.*\s+"
  [ "$kind_resource" = 'all' ] && grep_filter="${start_pattern}${kind_pattern}[^/]*\/[^\s]*${name_pattern}.*\s"

  [ -n "$verbose" ] && echo "Regular output filtered with grep: '${grep_filter}'"
  command="kubectl get $kind_resource $namespace_argument $context_argument | grep -iP \"$grep_filter\""
else
  #Assemble jq filter for JSON output
  [ "$name_pattern" != '' ] && jq_filter="${jq_filter}select(.metadata.name | test(\"${name_pattern//\\/\\\\}\"; \"i\")) | "
  [ "$kind_pattern" != '' ] && jq_filter="${jq_filter}select(.kind | test(\"${kind_pattern//\\/\\\\}\"; \"i\")) | "
  [ "$label_pattern" != '' ] && jq_filter="${jq_filter}select(.metadata.labels | values[] | test(\"${label_pattern//\\/\\\\}\"; \"i\")) | "
  jq_filter="${jq_filter}{ kind, name: .metadata.name, namespace: .metadata.namespace"
  [ "$kind_resource" = 'pod' ] || [ "$kind_resource" = 'all' ] && jq_filter="${jq_filter}, podStatus: .status.phase"
  [ "$kind_resource" = 'replicaset' ] || [ "$kind_resource" = 'deploy' ] || [ "$kind_resource" = 'deployment' ] || \
    [ "$kind_resource" = 'statefulset' ] || [ "$kind_resource" = 'all' ] && \
    jq_filter="${jq_filter}, controllerReplicasReady: .status.readyReplicas, controllerReplicas: .status.replicas"
  [ "$kind_resource" = 'job' ] || [ "$kind_resource" = 'all' ] && jq_filter="${jq_filter}, jobSucceeded: .status.succeeded"
  [ "$json_extra_mapping" != '' ] && jq_filter="${jq_filter}, ${json_extra_mapping}"
  jq_filter="${jq_filter} }"

  [ -n "$verbose" ] && echo "JSON output filtered with jq: '${jq_filter}'"
  command="kubectl get $kind_resource $namespace_argument $context_argument -o=json | jq '$jq_filter'"
fi

[ -n "$verbose" ] && echo "Full command: ${command}"
[ -n "$verbose" ] && echo "============= Running"
bash -c "$command"
[ -n "$verbose" ] && echo "============= ktnxbye"
