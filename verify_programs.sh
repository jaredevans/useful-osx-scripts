#!/bin/sh

echo "Checking the signature of every program running on the system...."
echo " "
rm -f codesign.log

for i in `ps axo pid` 
do 
  echo "----- PID $i -----" >> codesign.log
  codesign -dvv $i 2>> codesign.log 
  printf . 
done 
echo " "

egrep -i "(Executable|Identifier=|Authority=Developer ID App|PID)" codesign.log | grep -v Platform | grep -v Team | grep -B3 Authority=

echo " "
echo "Check the file codesign.log for full log."
