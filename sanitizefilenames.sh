#!/bin/bash

# *** WARNING *** --- This *is* a very dangerous script to run!

# To protect newbies from destroying their machines:
# You are required to change the hard coded directory below to a directory where
# files (or directories of files)  will be moved to then renamed.

# This script will recursively visit current directory and all sub-directories
# and get rid of problematic characters in filenames and sanitize the file name.

# The non-standard characters in file names are replaced with an underscore:
# space , - , comma , ! , ' , # , __ , ___ , ; , & , ( , ) 

# After files are renamed, they can be mass processed by other scripts 
# with more predictable results.

SAVEIFS=$IFS
export IFS=$'\n';
CDIR=$(pwd)

if (pwd | grep -c '/Users/jared/files_to_rename'); then
   echo "Correct Directory - Proceeding..."
else
   echo "Wrong Directory - Terminating now to avoid hosing your machine."
   exit 0
fi

for i in `find $CDIR -type d -print`; do
  DIR=$i
  cd "$DIR"
  echo echo "In $DIR"
  find . -maxdepth 1 -type f \( -iname "* *" \) -exec bash -c 'mv "$0" "${0//\ /_}"' {} \;
  find . -maxdepth 1 -type f \( -iname "*-*" \) -exec bash -c 'mv "$0" "${0//\-/_}"' {} \;
  find . -maxdepth 1 -type f \( -iname "*,*" \) -exec bash -c 'mv "$0" "${0//\,/_}"' {} \;
  find . -maxdepth 1 -type f \( -iname "*\!*" \) -exec bash -c 'mv "$0" "${0//\!/_}"' {} \;
  find . -maxdepth 1 -type f \( -iname "*\'*" \) -exec bash -c 'mv "$0" "${0//\'"'"'/_}"' {} \;
  find . -maxdepth 1 -type f \( -iname "*#*" \) -exec bash -c 'mv "$0" "${0//#/_}"' {} \;
  find . -maxdepth 1 -type f \( -iname "*___*" \) -exec bash -c 'mv "$0" "${0//___/_}"' {} \;
  find . -maxdepth 1 -type f \( -iname "*__*" \) -exec bash -c 'mv "$0" "${0//__/_}"' {} \;
  find . -maxdepth 1 -type f \( -iname "*;*" \) -exec bash -c 'mv "$0" "${0//;/_}"' {} \;
  find . -maxdepth 1 -type f \( -iname "*&*" \) -exec bash -c 'mv "$0" "${0//&/_}"' {} \;
  find . -maxdepth 1 -type f \( -iname "*(*" \) -exec bash -c 'mv "$0" "${0//\(/_}"' {} \;
  find . -maxdepth 1 -type f \( -iname "*)*" \) -exec bash -c 'mv "$0" "${0//\)/_}"' {} \;
  for f in `find . -maxdepth 1 -type f` ; do mv -v $f `echo $f | tr '[A-Z]' '[a-z]'` ; done
  cd "$CDIR"
done

IFS=$SAVEIFS
