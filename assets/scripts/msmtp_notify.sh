#!/bin/bash


[ ! -z $DEBUG  ] && set -x
set -o pipefail

(envsubst < /usr/share/msmtprc/email_template.dist && tee >(jq -r .stdout) >(jq -r .stderr)  >/dev/null) | msmtp ${SMTP_TO}
