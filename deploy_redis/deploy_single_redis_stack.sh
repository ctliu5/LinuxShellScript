#!/usr/bin/env bash
#
# deploy_single_redis_stack.sh
# 目的：自動部署單機版本 Redis-stack，在本機上以 Docker Container 執行
# 使用範例：
#   1) chmod +x deploy_single_redis_stack.sh
#   2) ./deploy_single_redis_stack.sh
#

# ------------------ 使用者可調整參數 ------------------
CONTAINER_NAME="redis-stack"
IMAGE_NAME="redis/redis-stack:7.4.0-v1"
BASE_DIR="$(pwd)"        # 預設使用目前目錄
LOG_DIR="${BASE_DIR}/logs"
REMOVE_OLD_CONTAINER="false"

# -e REDIS_ARGS 中的配置範例
REDIS_ARGS='--logfile /logs/log_redis-server.log --maxmemory 12884901888'
PORT_MAPPING="-p 6379:6379 -p 8001:8001 -p 26379:26379"

# ------------------ 函式：顯示訊息 ------------------
info()    { echo -e "\033[1;34m[Info]\033[0m  $*"; }
warn()    { echo -e "\033[1;33m[警告]\033[0m $*"; }
error()   { echo -e "\033[1;31m[錯誤]\033[0m $*"; }
success() { echo -e "\033[1;32m[成功]\033[0m $*"; }

# ------------------ Step 1: 建立資料夾 ------------------
info "=== 1. 建立 logs 資料夾 (若尚未建立) ==="
if [ ! -d "${LOG_DIR}" ]; then
  mkdir -p "${LOG_DIR}"
  success "已建立資料夾: ${LOG_DIR}"
else
  info "資料夾已存在: ${LOG_DIR} (略過)"
fi

# ------------------ Step 2: 檢查舊容器是否存在 ------------------
info "=== 2. 檢查舊容器 (名稱：${CONTAINER_NAME}) ==="
EXIST_CONTAINER=$(docker ps -a --format '{{.Names}}' | grep "^${CONTAINER_NAME}$")
if [ -n "${EXIST_CONTAINER}" ]; then
  info "容器 ${CONTAINER_NAME} 已存在。"

  if [ "${REMOVE_OLD_CONTAINER}" = "true" ]; then
    info "REMOVE_OLD_CONTAINER=true，將移除舊容器..."
    docker rm -f "${CONTAINER_NAME}" && success "已移除舊容器 ${CONTAINER_NAME}。" || error "移除容器失敗。"
  else
    info "REMOVE_OLD_CONTAINER=false，保留舊容器 (若已在執行中則不重啟)。"
  fi
else
  info "容器 ${CONTAINER_NAME} 不存在，稍後將新建。"
fi

# ------------------ Step 3: 啟動容器 (若尚未在執行) ------------------
info "=== 3. 啟動 Docker 容器 (redis-stack) ==="

RUNNING=$(docker ps --format '{{.Names}}' | grep "^${CONTAINER_NAME}$")
if [ -z "${RUNNING}" ]; then
  # 容器未在執行 -> 建立並啟動
  docker run \
    -v "${LOG_DIR}:/logs" \
    --name "${CONTAINER_NAME}" \
    ${PORT_MAPPING} \
    -d \
    -e REDIS_ARGS="${REDIS_ARGS}" \
    "${IMAGE_NAME}"
  
  if [ $? -eq 0 ]; then
    success "容器 ${CONTAINER_NAME} 啟動成功！"
  else
    error "容器 ${CONTAINER_NAME} 無法啟動，請檢查錯誤訊息。"
    exit 1
  fi
else
  info "容器 ${CONTAINER_NAME} 已在執行中，略過啟動步驟。"
fi

# ------------------ Step 4: 簡易檢查 ------------------
info "=== 4. 簡易檢查 ==="
docker ps | grep "${CONTAINER_NAME}" &>/dev/null
if [ $? -eq 0 ]; then
  success "部署完成，可使用 'docker logs ${CONTAINER_NAME}' 觀察日誌或執行其他動作。"
else
  error "容器 ${CONTAINER_NAME} 未在執行中，請手動檢查。"
fi
