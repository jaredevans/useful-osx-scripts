#!/bin/sh

# Corresponding apps with the network connections they are listening on or actively using.

IFS="
"
function show_all
{
    while test $# -gt 0
    do
	processid=`echo $1 | awk 'NF>1{print $NF}'`
           cmdline=`sudo ps -p $processid | awk '{$1="";$2="";$3=""; print $0}' | grep -v CMD | sed -e 's/^[ \t]*//'`
           fulline=`echo $1 $cmdline`
	   echo "$fulline" 
        shift
    done
}

echo "Proto   Local                     Address                                                   State        PID        CMDLINE"
noutput=`sudo netstat -Wav -f inet | sort -u -k5 |awk '{print $1, $4, $5, $6, $(NF-1)}' |egrep -v 'Proto|including|Active' | column -t`
show_all $noutput
unset IFS
