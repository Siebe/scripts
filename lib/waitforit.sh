#!/usr/bin/env bash

usage () {
  if [ -z "$quiet" ]; then
    echo 'Wait for certain output of something and stop that something... yeah just like that.'
    echo 'Either run and keep repeating a command within this script or pipe something to it'
    echo ' ./waitforit.sh [-tFStmrkv] [-c COMMAND] [-t SLEEPTIME] [-T TIMEOUT] [-R RETRIES] [-K SIGNAL] -- TESTSTRING'
    echo 'TESTSTRING = string to test with'
    echo '-c COMMAND = command to run and repeat, if omitted listen to lines from STDIN'
    echo '-t SLEEPTIME = seconds to sleep between command repeat, 0 means no repeat (default: 0)'
    echo '-T TIMEOUT = stop after TIMEOUT seconds, 0 is no timeout (default: 0)'
    echo '-R RETRIES = stop after repeating RETRIES times (default: infinite)'
    echo '-F = ignore command failure and keep repeating after non-zero exit codes'
    echo '-S = ignore STDERR from command, else take STDERR in the result to be tested'
    echo '-m = multiline mode; command only'
    echo '-r = regex mode, TESTSTRING is now simple regex pattern; no multiline'
    echo '-k = king mode, kill parent process, instead of just siblings; no command only'
    echo '-K SIGNAL = kill signal, choose your murder weapon (default: 1)'
    echo '-v = verbose mode'
    echo '-q = quiet mode, combine with -k for ninja mode'
  fi
}

my_pid=$$
parent_pid=$(ps -o ppid= -p ${my_pid})
command=""
sleep_time=1
repeats=0
kill_signal=1
bold=$(tput bold)
normal=$(tput sgr0)

while getopts ":hc:t:T:R:FSmrkK:vq" options
do
	case $options in
			h ) usage; examples; exit 0;;
   		c ) command="${OPTARG}";;
      t ) sleep_time="${OPTARG}";;
      T ) timeout="${OPTARG}";;
      R ) max_repeat="${OPTARG}";;
      F ) ignore_fail=1;;
      S ) ignore_stderr=1;;
      m ) multiline=1;;
      r ) regex=1;;
      k ) kill_parent=1;;
      K ) kill_signal="${OPTARG}";;
      v ) verbose=1;;
      q ) quiet=1;;
      ? ) >&2 echo 'Error: invalid option'; usage; exit 1;;
	esac
done

shift $(($OPTIND - 1))
expected_string="$@"

[ -n "$quiet" ] && unset verbose
[ -z "$expected_string" ] && { [ -z "$quiet" ] && >&2 echo 'Error: TESTSTRING required'; usage; exit 1; }
[ -n "$multiline" ] && [ -n "$regex" ] && { [ -z "$quiet" ] && >&2 echo 'Error: Can not use regex and multiline mode simultaneously'; usage; exit 1; }
if [ -n "$command" ]; then
  [ -n "$kill_parent" ] && unset kill_parent && [ -z "$quiet" ] && echo "Warning: can not kill parent when running command as child"
  [ "$sleep_time" -lt 1 ] && sleep_time=1 && [ -z "$quiet" ] && echo "Warning: SLEEPTIME can not be less than 1"
else
  if [ "$kill_signal" -lt 0 ] || [ "$kill_signal" -gt 64 ]; then
    [ -z "$quiet" ] && >&2 echo 'Error: invalid KILLSIGNAL'; usage; exit 1;
  fi
  [ -n "$multiline" ] && unset multiline && [ -z "$quiet" ] && echo "Warning: can not use multiline with in stdin mode"
  if [ -n "$ignore_fail" ] || [ -n "$ignore_stderr" ]; then
    unset $ignore_fail
    unset $ignore_stderr
    [ -z "$quiet" ] && echo "Warning: can not ignore failure or stderr in stdin mode"
  fi
fi

#always redirect the stderr of command
if [ -n "$command" ]; then
  full_command=$command
  if [ -n "$ignore_stderr" ]; then
    full_command+=" 2> /dev/null"
  else
    full_command+=" 2>&1"
  fi
fi

if [ -n "$verbose" ]; then
  echo "${bold}Expected string   : ${normal}${expected_string}"
  if [ -n "$command" ]; then
    echo "${bold}Command           : ${normal}${command}"
    echo "${bold}Full Command      : ${normal}${full_command}"
    echo "${bold}Sleep Time        : ${sleep_time} seconds"
    echo -n "${bold}Timeout           : "; [ -z "$timeout" ] && echo "none" || echo "$timeout seconds${normal}"
    echo -n "${bold}Max Repeats       : "; [ -z "$max_repeat" ] && echo "infinite" || echo "$max_repeat${normal}"
    echo -n "${bold}Ignore Fail       : "; [ -z "$ignore_fail" ] && echo "no" || echo "yes${normal}"
    echo -n "${bold}Ignore stderr     : "; [ -z "$ignore_stderr" ] && echo "no" || echo "yes${normal}"
    echo -n "${bold}Multiline         : "; [ -z "$multiline" ] && echo "no" || echo "yes${normal}"
  else
    echo -n "${bold}Kill parents      : "; [ -z "$kill_parent" ] && echo "no" || echo "yes${normal}"
    echo "${bold}Kill signal       : ${kill_signal}"
  fi
  echo -n "${bold}Regex             : "; [ -z "$regex" ] && echo "no" || echo "yes${normal}"
  echo "${bold}PID              : ${my_pid}${normal}"
  echo "${bold}Parent PID       : ${parent_pid}${normal}"

fi

#run before exiting
finish () {
  if [ -n "$timeout_pid" ] && ( ps -p $timeout_pid > /dev/null ); then
    [ -n "$verbose" ] && echo "${bold}killing timeout process $timeout_pid${normal}"
    kill -s 1 "$timeout_pid"
  fi
  if [ -z "$command" ]; then
    if [ -z "$kill_parent" ]; then
      [ -n "$verbose" ] && echo "${bold}Killing siblings ${normal}"
      #to kill everything in the same pipe, we assemble all other PID's in the group that are LOWER than our own PID,
      #and HIGHER than the direct parent PID
      pgid=$( ps -o '%r' $my_pid | grep -Po '\b\d+\b' )
      process_group=($(pgrep -g $pgid | sort))
      for member_pid in "${process_group[@]}"; do
        if [ "$member_pid" -lt "$my_pid" ] && [ "$member_pid" -gt "$parent_pid" ] ; then
          [ -n "$verbose" ] && echo "${bold}Killing PID ${member_pid} ${normal}"
          kill -s $kill_signal $member_pid
        fi
      done;
    else
      [ -n "$verbose" ] && echo "${bold}Killing parent, PID ${parent_pid} ${normal}"
      #would be great if there was a way to suppress the "hangup" message and the 129 return code
      kill -s $kill_signal $parent_pid
    fi
  fi
  exit 0
}

on_term () {
  [ -n "$verbose" ] && echo "${bold}Receiving TERM signal${normal}"
  finish
}

# Execute function on_term() receiving TERM signal
trap on_term TERM

#run a string test
runTest () {
  test_lines=$1
  expected_string=$2
  if [ -z "$multiline" ]; then
    while IFS= read -r test_line; do
        [ -n "$verbose" ] && echo -n "${bold}Testing line: ${normal}${test_line}" && echo "${bold} against expected: ${normal}${expected_string}"
        if ( [ -n "$regex" ] && ( echo "$test_line" | grep "$expected_string" -c 2> /dev/null 1> /dev/null ) )\
        || ( [ -z "$regex" ] && [ "$test_line" = "$expected_string" ] ); then
           [ -n "$verbose" ] && echo "${bold}Match found, goodbye!${normal}"
          finish
        fi
    done <<< "$test_lines"
  else
    [ -n "$verbose" ] && printf "${bold}Testing lines: ${normal}\n${test_lines}\n${bold}Against expected: ${normal}\n${expected_string}\n"
    if [ "$test_lines" = "$expected_string" ]; then
      [ -n "$verbose" ] && echo "${bold}Match found, goodbye!${normal}"
      finish
    fi
  fi
}

#start a separate timeout process that will kill main process
runTimeOut () {
  time=$1
  pid=$2
  sleep $time
  [ -z "$quiet" ] && echo "${bold}Timed out, killing pid $pid${normal}"
  ( ps -p $pid > /dev/null ) && kill $pid
}

if [ -n "$timeout" ] && [ "$timeout" -gt 0 ]; then
  runTimeOut "$timeout" "$$" &
  timeout_pid="$!"
  [ -n "$verbose" ] && echo "${bold}Timeout process has pid $timeout_pid${normal}"
fi

#Start processing here
if [ -n "$command" ]; then
  #Ether run a command in a loop, check the result per line or multiline and sleep every loop
  while [ -z "$result_found" ]; do
    [ -z "$quiet" ] && echo "${bold}Running : ${normal}${full_command}"
    result=$(eval "$full_command")
    exit_code="$?"
    [ -z "$quiet" ] && echo "${bold}Result  : ${normal}${result}"
    if [ -z "$ignore_fail" ] && [ "$exit_code" -ne 0 ]; then
      [ -z "$quiet" ] && echo >&2 "${bold}Command failed with exit code ${exit_code}${normal}"
      exit $exit_code
    fi
    runTest "$result" "$expected_string"
    ( [ "$sleep_time" -lt 1 ] || ( [ -n "$max_repeat" ] && [ "$max_repeat" -eq 1 ] ) ) && finish
    if [ -n "$max_repeat" ]; then
      if [ "$repeats" -ge "$max_repeat" ]; then
        [ -z "$quiet" ] && echo "${bold}Stopping after ${repeats} repeats${normal}"
        finish
      fi
      let "repeats=repeats+1"
    fi
    [ -n "$verbose" ] && echo "${bold}Repeating in ${sleep_time} seconds${normal}"
    sleep $sleep_time
  done
else
  #Or take lines from stdin in a loop and check these
  [ -n "$verbose" ] && echo "${bold}Listening to /dev/stdin${normal}"
  while read input_line; do
    [ -z "$quiet" ] && echo "${bold}Input line: ${normal}${input_line}"
    runTest "$input_line" "$expected_string"
  done < /dev/stdin
fi


