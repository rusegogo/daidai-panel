#!/bin/sh
# ================= 配置区域 =================
# 远程名称（自定义，需与下面 B2 配置对应）
REMOTE_NAME="daidai_b2"

# Backblaze B2 凭据文件
B2_KEY_ID_FILE="/etc/secrets/B2_KEY_ID"
B2_APP_KEY_FILE="/etc/secrets/B2_APP_KEY"

# 要同步的桶名与可选路径（例如：bucket-name 或 bucket-name/folder）
B2_BUCKET_PATH="${B2_BUCKET_PATH:-daidai-panel-backups}"

# 备份名称（由 entrypoint 通过环境变量传入）
BACKUP_NAME="${BACKUP_NAME:-fromb2.tgz}"

# 数据目录（entrypoint 已 export，这里做兜底）
DATA_DIR="${DATA_DIR:-/app/Dumb-Panel}"

# 本地目标目录
LOCAL_DIR="${DATA_DIR}/backups"

# 数据库文件（用于判断是否需要恢复）
DB_FILE="${DATA_DIR}/daidai.db"
# ============================================

log() {
  printf '%s [restore] %s\n' "$(date '+%Y/%m/%d %H:%M:%S')" "$*"
}

fail() {
  printf '%s [restore][ERROR] %s\n' "$(date '+%Y/%m/%d %H:%M:%S')" "$*" >&2
  exit 1
}

# --- 1. 参数校验 -----------------------------------------------------------
if [ -z "${BACKUP_NAME}" ]; then
  fail "未设置 BACKUP_NAME 环境变量，跳过 B2 恢复"
fi

if [ -z "${B2_BUCKET_PATH}" ] || [ "${B2_BUCKET_PATH}" = "占位符" ]; then
  fail "B2_BUCKET_PATH 未配置，跳过 B2 恢复"
fi

# --- 2. 幂等：daidai.db 已存在且非空就跳过 ---------------------------------
if [ -s "${DB_FILE}" ]; then
  log "daidai.db 已存在且非空（${DB_FILE}），跳过 B2 恢复"
  exit 0
fi

# --- 3. 检查 rclone --------------------------------------------------------
if ! command -v rclone >/dev/null 2>&1; then
  fail "未找到 rclone。请在 Dockerfile 中安装（Alpine：apk add rclone），或改用带 rclone 的镜像"
fi

# --- 4. 检查凭据文件 -------------------------------------------------------
if [ ! -r "${B2_KEY_ID_FILE}" ]; then
  fail "B2 凭据文件不可读：${B2_KEY_ID_FILE}，跳过 B2 恢复"
fi
if [ ! -r "${B2_APP_KEY_FILE}" ]; then
  fail "B2 凭据文件不可读：${B2_APP_KEY_FILE}，跳过 B2 恢复"
fi

B2_KEY_ID=$(cat "${B2_KEY_ID_FILE}") || fail "读取 ${B2_KEY_ID_FILE} 失败"
B2_APP_KEY=$(cat "${B2_APP_KEY_FILE}") || fail "读取 ${B2_APP_KEY_FILE} 失败"

if [ -z "${B2_KEY_ID}" ] || [ -z "${B2_APP_KEY}" ]; then
  fail "B2 凭据为空（${B2_KEY_ID_FILE} / ${B2_APP_KEY_FILE}），跳过 B2 恢复"
fi

# --- 5. 幂等配置 rclone remote ---------------------------------------------
if rclone listremotes 2>/dev/null | grep -qx "${REMOTE_NAME}:"; then
  log "rclone remote ${REMOTE_NAME} 已存在，跳过创建"
else
  log "正在配置 rclone remote ${REMOTE_NAME}..."
  if ! rclone config create "${REMOTE_NAME}" b2 \
      account="${B2_KEY_ID}" \
      key="${B2_APP_KEY}" \
      hard_delete=false \
      --non-interactive >/dev/null 2>&1; then
    fail "创建 rclone remote ${REMOTE_NAME} 失败"
  fi
fi

# --- 6. 确保本地目录存在 ---------------------------------------------------
mkdir -p "${LOCAL_DIR}" || fail "无法创建本地目录 ${LOCAL_DIR}"

# --- 7. 只同步指定备份文件 -------------------------------------------------
REMOTE_SRC="${REMOTE_NAME}:${B2_BUCKET_PATH}/${BACKUP_NAME}"
log "开始同步 ${REMOTE_SRC} → ${LOCAL_DIR}"

if ! rclone copy "${REMOTE_SRC}" "${LOCAL_DIR}" \
    --transfers 4 \
    --checkers 8 \
    --retries 3; then
  fail "rclone 同步失败：${REMOTE_SRC}"
fi

pwd
whoami
ls /app/
ls -lt /app/Dumb-Panel/
cat /app/config.yaml
# --- 8. 调用 ddp 恢复 ------------------------------------------------------
log "执行 ddp backup restore ${BACKUP_NAME}"
if ! ddp backup restore "${BACKUP_NAME}"; then
  fail "ddp backup restore ${BACKUP_NAME} 失败"
fi
ls /app/
ls -lt /app/Dumb-Panel/
cat /app/config.yaml
log "B2 恢复完成：${BACKUP_NAME}"
exit 0
