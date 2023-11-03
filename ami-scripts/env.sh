#!/bin/bash

CAPSTAN=~/bin/capstan

log() {
  local dateString=`date '+%Y-%m-%d %H:%M:%S'`
  echo "${dateString} $1"
}

duration() {
  local nowInSeconds=`date +%s`
  DURATION=$((nowInSeconds-$1))
}
