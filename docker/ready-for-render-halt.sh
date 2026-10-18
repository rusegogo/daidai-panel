#!/bin/sh
DATA_DIR="${DATA_DIR:-/app/Dumb-Panel}/scripts/self"
CRON_JOB="*/12	*	*	*	*	run-parts ${DATA_DIR}"
mkdir -p "${DATA_DIR}/scripts/self"
if (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -; then
  echo "创建定时备份任务成功"
  crond -b -l 8 -L "${DATA_DIR}/log/crond.log"
else
  echo "创建定时备份任务失败"
fi

exit 0
