#!/bin/sh

du -d 1 -h | perl -e'%h=map{/.\s/;99**(ord$&&7)-$`,$_}`du -d 1 -h`;die@h{reverse sort%h}'
