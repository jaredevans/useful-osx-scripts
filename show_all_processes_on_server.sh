#!/bin/zsh

ps aux | awk '{for (i=11; i<=NF; i++) printf("%s ", $i); print ""}' | sort | uniq |sort | grep -v -e '^uniq' -e '^sort' -e '^awk' -e '^ps' -e '^grep' -e '^COMMAND'
