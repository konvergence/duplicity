#!/usr/bin/env bash


#any error on script stop the script
#set -e

[ ! -z $DEBUG  ] && set -x

# manage timezone
if [ ! -z "$TZ" ]; then
   echo "$TZ" > /etc/timezone
   rm /etc/localtime
   dpkg-reconfigure -f noninteractive tzdata > /dev/null
fi

exec /bin/entrypoint.sh $@

