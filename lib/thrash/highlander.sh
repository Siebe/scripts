#!/bin/sh
# highlander - there can be only one
# usage: highlander [-f pidfile] command [args ...]
# $Id: highlander 153235 2018-05-14 10:51:21Z dick $
# $URL: file:///e/svnrepo/netbootconfs/trunk/overlays/poi-conf/usr/local/bin/highlander $

_XPG=1						# posix compliance on irix
myname=${0/*\//}
pidfile=/var/run/highlander.pid
quiet=false
kill=false
confused=false
maxage=0
maxlinger=0
exiterror=1
unset logfile
logpid=false
usage="$myname [options] command [args ...]
Options
	-q		Be quiet when this instance cannot run
	-i		Ignore error when this instance cannot run
	-k		Kill running process
	-f file		Specify alternative pid pidfile (default $pidfile)
	-w maxage	Warn if running pid older than maxage secs
	-l maxlinger	Try to get the lock for at most maxlinger secs
	-L logfile	keep runtime stats in logfile
	-P		log pid in logfile
"

die() { echo "$*" >&2; exit 1; }
warn() { echo "$*" >&2; }

lock()
{
	local pidfile=$1; shift
	local comment="$*"
	local pid rest success=true

	# open the lockfile read/write
	# unfortunately bash cannot seek in filedescriptors, so
	# we use a dirty trick: open the same file twice. One
	# for reading (fd 4) and one for writing (fd 5)
	exec 4<>"$pidfile" || die "cannot open $pidfile"
	exec 5<>"$pidfile" || die "cannot open $pidfile"
	read pid rest <&4
	exec 4>&-;		# close fd 4

	if [ -n "$pid" -a "$pid" != $$ ]; then # uhoh, a competitor
		if kill -0 "$pid" 2>/dev/null ||
					[ -f "/proc/$pid/status" ]; then
			success=false;	# did not get the lock :-(
		fi
	fi
	if $success; then
		# got it!
		echo "$$ $comment" >&5
	fi
	exec 5>&-;	# close fd 5
	$success
}

unlock()
{
	local pidfile="$1"
	rm -f "$pidfile"
}

# parse options
while getopts "f:qikw:l:L:Ph" c; do
	case "$c" in
		f) pidfile="$OPTARG";;
		q) quiet=true;;
		i) exiterror=0;;
		k) kill=true;;
		w) maxage="$OPTARG";;
		l) maxlinger="$OPTARG";;
		L) logfile="$OPTARG";;
		P) logpid=true;;
		*) confused=true;;
	esac
done

# remove options from command line
shift $((OPTIND - 1))

if $confused || [ -z "$*" ]; then
	die "$usage"
fi

# linger a bit if desired & needed
i=0;
while [ $i -lt $maxlinger ] && ! lock "$pidfile" $$ "wait: $*" ; do
	sleep 1
	i=$((i+1))
done

# check for other incarnation
if ! lock "$pidfile" $$ "pre: $*"; then
	# hope $pidfile still exists :)
	read lockpid killpid cmd <"$pidfile" || die "Cannot read $pidfile"
	#
	# Tell the world another instance is running
	$quiet || warn "$0: already running [$lockpid] [$killpid] $cmd"
	#
	# If another incarnation is running, we're going to issue
	# a warning if it started before $maxage seconds ago
	if [ "$maxage" -gt 0 ]; then
		startdate=$(stat -c '%Y' "$pidfile")
		now=$(date '+%s')
		elapsed=$((now - startdate))
		[ $elapsed -ge $maxage ] &&
			warn "$0: Pid $pid is too old ($elapsed sec)"
	fi
	if $kill; then
		warn killing $killpid
		kill $killpid
	fi
	exit $exiterror;	# Not happy if we couldn't get the lock
fi

# we have the lock now. Assume we're going to unlock it later
unlock=true

# duplicate stdin to another filedescriptor, so we can use that fd as
# stdin for the command we're going to run
# ("$@" <&0 does work with bash, but not with /bin/sh on irix)
exec 3<&0

starttime=$(env -i PATH=/usr/bin:/bin date +%s)

# start the command
"$@" <&3 &
waitpid=$!

# update the lock with the pid of our child
# this is because we want our child to be killed by another incarnation
# of highlander, not this highlander instance itself.
if ! lock "$pidfile" "$waitpid" "main: $*"; then
	warn "uhoh, someone stole our pre lock, this should never happen"
	kill $waitpid
	unlock=false
fi

# install signal handler to clean up the mess in case of ^C etc.
trap 'kill "$waitpid"; echo killed "$waitpid" >&2;' 1 2 3 15

# and wait for its termination
wait $waitpid
ret=$?

# the lock goes back to this script
if ! lock "$pidfile" $$ "post: $*"; then
	warn "uhoh, someone stole our main lock, this should never happen"
	unlock=false
fi

endtime=$(env -i PATH=/usr/bin:/bin date +%s)
if [ -n "$logfile" ]; then
	if [ ! -f "$logfile" ]; then
		if $logpid; then
			printf '# %-15s %5s %5s %-24s %3s %s\n' \
				'date' 'elaps' 'pid' 'utimes' 'ret' 'command'
		else
			printf '# %-15s %5s %-24s %3s %s\n' \
				'date' 'elaps' 'utimes' 'ret' 'command'
		fi >"$logfile"
	fi
	now=$(env -i PATH=/usr/bin:/bin date '+%Y%m%d %H:%M:%S' )
	elapsed=$((endtime - starttime));
	# times must not be run in a subshell...
	timesfile=$(mktemp)
	times > $timesfile
	while read line; do tline="$line"; done <$timesfile
	rm -f "$timesfile"

	if $logpid; then
		printf '%-17s %5d %5d %-24s %3s %s\n' \
			"$now" "$elapsed" "$waitpid" "$tline" "$ret" "$*"
	else
		printf '%-17s %5d %-24s %3s %s\n' \
			"$now" "$elapsed" "$tline" "$ret" "$*"
	fi >> "$logfile"
fi

# unlock
$unlock && unlock "$pidfile"

# and exit with the commands exit status
exit "$ret"
