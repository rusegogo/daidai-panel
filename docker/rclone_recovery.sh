rclone config create b2remote b2 account "你的Application Key ID" key "你的Application Key"
#!/bin/sh

# ================= 配置区域 =================
# 远程名称（自定义，需与下面 B2 配置对应）
REMOTE_NAME="daidai_b2"

# Backblaze B2 凭据
# 在 B2 后台的 "Application Keys" 中创建，权限需包含 listBuckets, readFiles 等
B2_KEY_ID=$(cat /etc/secrets/B2_KEY_ID)
B2_APP_KEY=$(cat /etc/secrets/B2_APP_KEY)

# 要同步的桶名与可选路径（例如：bucket-name 或 bucket-name/folder）
B2_BUCKET_PATH="daidai-panel-backups"

# 本地目标目录（需确保存在或脚本自动创建）
LOCAL_DIR="/app/Dumb-Panel/backups"
BACKUP_NAME="fromb2"
# ============================================


# ============================================
# 1. 检查 rclone 是否安装
if ! command -v rclone >/dev/null 2>&1; then
    echo "错误：未找到 rclone，请先运行 apk add rclone 安装" >&2
    exit 1
fi

# 2. 创建（或更新）B2 远程配置
# 使用 --non-interactive 避免卡在交互问答，所有参数直接传入
echo "正在配置远程 ${REMOTE_NAME}..."
rclone config create "${REMOTE_NAME}" b2 \
    account="${B2_KEY_ID}" \
    key="${B2_APP_KEY}" \
    hard_delete=false \
    --non-interactive

if [ $? -ne 0 ]; then
    echo "错误：创建 rclone 远程配置失败" >&2
    exit 1
fi

# 3. 确保本地目录存在
mkdir -p "${LOCAL_DIR}"

# 4. 执行同步（远程 B2 → 本地目录）
# 注意：sync 会使本地目录与远程完全一致，本地多余的文件会被删除！
echo "开始同步 B2:${B2_BUCKET_PATH} → ${LOCAL_DIR}"
rclone sync "${REMOTE_NAME}:${B2_BUCKET_PATH}" "${LOCAL_DIR}" \
    --progress \
    --transfers 4 \
    --checkers 8 \
    --retries 3

if [ $? -eq 0 ]; then
    echo "同步完成。"
    ddp backup store $(BACKUP_NAME)
else
    echo "错误：同步过程中出现问题，请检查上方日志。" >&2
    exit 1
fi
