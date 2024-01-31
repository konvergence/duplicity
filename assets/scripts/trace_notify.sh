#!/bin/bash


[ ! -z $DEBUG  ] && set -x
set -o pipefail

cat >>/var/log/jobber_notify.log