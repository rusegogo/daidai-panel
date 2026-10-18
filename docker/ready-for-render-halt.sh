#!/bin/sh
DATA_DIR=${DATA_DIR:-/app/Dumb-Panel}
CRON_JOB="*/12	*	*	*	*	run-parts ${DATA_DIR}/scripts/self"
mkdir -p ${DATA_DIR}/scripts/self
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
