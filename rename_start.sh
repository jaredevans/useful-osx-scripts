#!/bin/bash

# *** WARNING *** --- This *is* a very dangerous script to run!

# To protect newbies from destroying their machines:
# You are required to change the hard coded directory below to a directory where
# files (or directories of files)  will be moved to then renamed.

# This script will recursively visit current directory and all sub-directories
# and replace the first few characters in filenames with the new set of characters

# Example: You can replace all 1.* files with the new name of 0001.*
# just enter 1 then 0001

SAVEIFS=$IFS
export IFS=$'\n';
CDIR=$(pwd)

read -p "starting name to replace: " startold
read -p "starting name to use instead: " startnew

echo "Renaming from ${startold} to ${startnew} ";\

if (pwd | grep -c '/Users/jared/files_to_rename'); then
   echo "Correct Directory, proceeding..."
   echo " "
else
   echo "Wrong Directory. Terminating now to prevent hosing of this machine."
   echo " "
   exit 0
fi

for i in `find $CDIR -type d -print`; do
  DIR=$i
  cd "$DIR"
  echo "Inside $DIR :"
 for file in `find . -maxdepth 1 -type f -iname "${startold}*"`; do
     sedstr=`echo "s/${startold}/${startnew}/"`
     newfile=`echo "${file}" | sed ${sedstr}`
     echo "moving ${file} to ${newfile}"
     mv ${file}  ${newfile}
  done
  cd "$CDIR"
done

IFS=$SAVEIFS
