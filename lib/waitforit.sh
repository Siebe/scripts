#!/usr/bin/env bash

usage () {
  echo 'Wait for certain output of something and stop'
	echo ' ./waitforit.sh [-tFStmrkv] [-c COMMAND] [-t SLEEPTIME] [-T TIMEOUT] [-R RETRIES] [-K SIGNAL] -- TESTSTRING'
	echo 'TESTSTRING = string to test with'
	echo '-c COMMAND = command to run and repeat, if omitted waitforit.sh will listen to lines from STDIN'
	echo '-t SLEEPTIME = seconds to sleep between command repeat, 0 means no repeat (default 0)'
	echo '-T TIMEOUT = stop after TIMEOUT seconds'
	echo '-R RETRIES = stop after repeating RETRIES times'
	echo '-F = ignore command failure (keep repeating on failure exit codes)'
	echo '-S = ignore STDERR from command, else take STDERR in the result to be tested'
	echo '-m = multiline mode, command only'
	echo '-r = regex mode, no multiline'
	echo '-k = kill parent'
	echo '-K SIGNAL = kill signal, what will kill your parent? (default: 1)'
	echo '-v = verbose mode'
}

my_pid=$$
command=""
sleep_time=1
repeats=0
kill_signal=1
bold=$(tput bold)
normal=$(tput sgr0)

while getopts ":hc:t:T:R:FSmrkK:v" options
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
      ? ) echo 'Error: invalid option'; usage; exit 1;;
	esac
done

shift $(($OPTIND - 1))
expected_string="$@"

[ -z "$expected_string" ] && { >&2 echo 'Error: TESTSTRING required'; usage; exit 1; }
[ -n "$multiline" ] && [ -n "$regex" ] && { >&2 echo 'Error: Can not use regex and multiline mode simultaneously'; usage; exit 1; }
[ -n "$command" ] && [ -n "$kill_parent" ] && unset kill_parent && echo "Warning: can not kill parent when running command as child"
[ -n "$command" ] && [ "$sleep_time" -lt 1 ] && sleep_time=1 && echo "Warning: can not kill parent when running command as child"
[ -z "$command" ] && [ -n "$multiline" ] && unset multiline && echo "Warning: can not use multiline with stdin"

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

  fi
fi

finish () {
  if [ -n "$timeout_pid" ] && ( ps -p $timeout_pid > /dev/null ); then
    [ -n "$verbose" ] && echo "${bold}killing timeout process $timeout_pid${normal}"
    kill -s 1 "$timeout_pid"
  fi
  if [ -n "$kill_parent" ]; then
    [ -n "$verbose" ] && echo "${bold}Killing parents${normal}"
    kill -s $kill_signal 0
  fi
  exit 0
}

on_term () {
  [ -n "$verbose" ] && echo "${bold}Receiving TERM signal${normal}"
  finish
}
# Execute function on_term() receiving TERM signal
trap 'on_term' TERM

runTest () {
  test_lines=$1
  expected_string=$2
  if [ -z "$multiline" ]; then
    while IFS= read -r test_line; do
        [ -n "$verbose" ] && echo -n "${bold}Testing line: ${normal}${test_line}" && echo "${bold} against expected: ${normal}${expected_string}"
        if [ "$test_line" = "$expected_string" ]; then
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

runTimeOut () {
  time=$1
  pid=$2
  sleep $time
  [ -n "$verbose" ] && echo "${bold}Timed out, killing PID $pid${normal}"
  ( ps -p $pid > /dev/null ) && kill $pid
}

if [ -n "$timeout" ] && [ "$timeout" -gt 0 ]; then
  runTimeOut "$timeout" "$$" &
  timeout_pid="$!"
  [ -n "$verbose" ] && echo "${bold}Timeout process has pid $timeout_pid${normal}"
fi

if [ -n "$command" ]; then
  while [ -z "$result_found" ]; do
    echo "${bold}Running: ${normal}${full_command}"
    result=$(eval $full_command)
    exit_code="$?"
    echo "${bold}Result: ${normal}${result}"
    if [ -z "$ignore_fail" ] && [ "$exit_code" -ne 0 ]; then
      echo "${bold}Command failed with exit code ${exit_code}${normal}"
      exit $exit_code
    fi
    runTest "$result" "$expected_string"
    ( [ "$sleep_time" -lt 1 ] || ( [ -n "$max_repeat" ] && [ "$max_repeat" -eq 1 ] ) ) && finish
    if [ -n "$max_repeat" ]; then
      let "repeats=repeats+1"
      if [ "$repeats" -ge "$max_repeat" ]; then
         echo "${bold}Stopping after ${repeats} repeats${normal}"
        finish
      fi
    fi
    [ -n "$verbose" ] && echo "${bold}Repeating in ${sleep_time} seconds${normal}"
    sleep $sleep_time
  done
else
  while read input_line && [ -z "$result_found" ]; do
    echo "${bold}Input line: ${normal}${input_line}"
    runTest "$input_line" "$expected_string"
  done
fi


