#!/usr/bin/env bash
#
# deploy_single_seq.sh
# 目的：自動部署單機版本 datalust/seq，在本機上以 Docker Container 執行
# 使用範例：
#   1) chmod +x deploy_single_seq.sh
#   2) ./deploy_single_seq.sh
#

# ------------------ 使用者可調整參數 ------------------
CONTAINER_NAME="seq"
IMAGE_NAME="datalust/seq:2024.3"
BASE_DIR="$(pwd)"                 # 預設使用目前目錄
DATA_DIR="${BASE_DIR}/seq-data"   # Seq 持久化數據目錄
REMOVE_OLD_CONTAINER="false"      # 是否移除舊容器
ACCEPT_EULA="Y"                   # 必須同意，才能運行映像

# :80 as the UI port. This port allows both ingestion and API requests.
# :5341 as the ingestion only port. This port doesn't allow API requests.
PORT_MAPPING="-p 80:80 -p 5341:5341"  # 這邊對外 port 設定與 container 內部相同

# ------------------ 函式：顯示訊息 ------------------
info()    { echo -e "\033[1;34m[Info]\033[0m  $*"; }
warn()    { echo -e "\033[1;33m[警告]\033[0m $*"; }
error()   { echo -e "\033[1;31m[錯誤]\033[0m $*"; }
success() { echo -e "\033[1;32m[成功]\033[0m $*"; }

# ------------------ Step 0: 檢查 Docker 環境 ------------------
info "=== 0. 檢查 Docker 是否安裝並運行 ==="
if ! command -v docker &> /dev/null; then
  error "Docker 未安裝或未加入 PATH，請先安裝 Docker。"
  exit 1
fi

# 進一步檢查 docker daemon 是否在執行
if ! sudo systemctl is-active --quiet docker; then
  error "Docker 服務未啟動，嘗試以 systemctl start docker 或重啟系統後再執行本腳本。"
  exit 1
fi

# ------------------ Step 1: 建立資料夾 ------------------
info "=== 1. 建立 logs 資料夾 (若尚未建立) ==="
if [ ! -d "${DATA_DIR}" ]; then
  mkdir -p "${DATA_DIR}"
  success "已建立資料夾: ${DATA_DIR}"
else
  info "資料夾已存在: ${DATA_DIR} (略過)"
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
info "=== 3. 啟動 Docker 容器 (seq) ==="

RUNNING=$(docker ps --format '{{.Names}}' | grep "^${CONTAINER_NAME}$")
if [ -z "${RUNNING}" ]; then
  # 容器未在執行 -> 建立並啟動
  docker run \
    --name "${CONTAINER_NAME}" \
    -d \
    --restart unless-stopped \
    -e ACCEPT_EULA=Y \
    -v "${DATA_DIR}:/data" \
    ${PORT_MAPPING} \
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
