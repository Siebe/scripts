#!/usr/bin/env bash

KUBECTL_CONTEXT=${KUBECTL_CONTEXT-''}
KUBECTL_NAMESPACE=${KUBECTL_NAMESPACE-''}
kget_arguments=' -j'
kget_command=''
restart_arguments=''
restart_command=''
input_pattern=''

#https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
[ -n "$SCRIPT_DIR" ] && kget_executable="${SCRIPT_DIR}/k8s/kget.sh" || \
  kget_executable="$(dirname -- "$( readlink -f -- "$0"; )")/kget.sh"

while getopts "hc:n:lv" options
do
	case $options in
		h ) usage; examples; exit 0;;
    c ) KUBECTL_CONTEXT=${OPTARG};;
    n ) KUBECTL_NAMESPACE=${OPTARG};;
    l ) label_pattern=1;; #lowercase
    v ) verbose=1;;
    ? ) echo 'Error: invalid option' >&2; usage; exit 1;;
	esac
done
shift $(($OPTIND - 1))

if [ $# -eq 1 ] ; then
  #one argument found, namespace to lowercase
  input_pattern="${1,,}"
fi
if [ $# -ge 2 ] ; then
  #two arguments found, pattern to lowercase
  KUBECTL_NAMESPACE="${1,,}"
  input_pattern="${2,,}"
fi

if [ "$KUBECTL_CONTEXT" != '' ]; then
  kget_arguments="${kget_arguments} -c ${KUBECTL_CONTEXT}"
  restart_arguments="${restart_arguments} --context ${KUBECTL_CONTEXT}"
fi

if [ "$KUBECTL_NAMESPACE" != '' ]; then
  kget_arguments="${kget_arguments} -n ${KUBECTL_NAMESPACE}"
  restart_arguments="${restart_arguments} -n ${KUBECTL_NAMESPACE}"
fi

kget_command="${kget_executable}${kget_arguments} '(deploy|statefulset|replicaset)' ${input_pattern}"

echo $kget_command
