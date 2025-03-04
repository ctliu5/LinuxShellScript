# Redis-stack 部署說明

## 目錄

1. [簡介](#簡介)
2. [環境需求](#環境需求)
3. [部署步驟 - 單機版](#部署步驟-單機版)
4. [部署步驟 - Sentinel](#部署多機sentinel)
5. [常見操作 (單機版)](#常見操作-單機版)
6. [Sentinel 版本延伸](#sentinel-版本延伸)
7. [故障排除](#故障排除)

---

## 簡介

Redis-stack 為官方整合版的 Redis，內含 RedisJSON、Search、Graph、Bloom 等附加功能，也可同時啟用 Sentinel。此說明檔提供 **單機版** 以及啟用 **Sentinel** 模式（用於高可用）的操作指南。

---

## 環境需求

- **Docker** (建議版本 20.10+)  
- 開放連接埠：
  - 6379 (Redis)  
  - 8001 (Redis-stack UI, 可選)  
  - 26379 (Sentinel, 若需要啟用 sentinel 服務)  
- RAM 建議：若使用 Redis-stack 且啟用多種模組 (搜尋/JSON/圖形...)，至少 2GB 以上。

---

## 部署步驟-單機版

1. **檢查部署腳本**  
   - 取得 `deploy_single_redis_stack.sh` 腳本 (參考同目錄)  
   - 設定可執行權限：

     ```bash
     chmod +x deploy_single_redis_stack.sh
     ```

2. **執行自動部署腳本**  
   - 在目標資料夾下（例如 `~/redis_server_single/`）執行：

     ```bash
     ./deploy_single_redis_stack.sh
     ```

   - 腳本將自動：
     1. 建立 `logs/` 資料夾  
     2. 檢查舊容器（若設定 `REMOVE_OLD_CONTAINER="true"` 則會砍掉重建）  
     3. 啟動容器： `docker run -v logs:/logs --name redis-stack -p 6379:6379 ...`

3. **驗證部署**  
   - `docker ps` 查看是否有 `redis-stack` 容器在執行  
   - `docker logs redis-stack` 檢查日誌中是否有錯誤  
   - 測試連線：  

     ```bash
     redis-cli -p 6379 ping
     # 預期回傳 PONG
     ```  

## 部署多機Sentinel

1. **檢查部署腳本及設定conf檔**  
   - 在同一個資料夾內需要有以下三個檔案：`auto_deploy.sh` & `redis.conf` & `sentinel.conf`
   - 如果為要部署slave節點，檢查`redis.conf`的最後一行是否為`replicaof {master node ip} {master node redis server port}`。例如：`replicaof 192.168.210.111 6379`
   - `sentinel.conf`不管部署在哪一台，都要指向唯一的master節點，增加最後一行`sentinel monitor mymaster {master node ip} {master node redis server port} {Quorum}` 。例如：`sentinel monitor mymaster 192.168.210.111 6379 2`
   - `auto_deploy.sh` 腳本 會執行以下動作：
     1. 建立資料夾結構（`redis/logs/`, `redis/pid/`, `sentinel/redis-sentinel/conf/` 等）  
     2. 複製 `redis.conf`, `sentinel.conf` 到對應路徑  
     3. 檢查並(選擇性)移除舊容器 (`REMOVE_OLD_CONTAINERS="true"` 時)  
     4. 啟動 `redis-stack` 容器 (Master)  
     5. 啟動 `redis-sentinel` 容器  
     6. 設定 logrotate 與 crontab  
   - 設定可執行權限：

     ```bash
     chmod +x auto_deploy.sh
     ```

2. **執行自動部署腳本**  
   - 在每台目標主機（或同一台以不同埠 / 不同資料夾）下執行：

     ```bash
     ./auto_deploy.sh
     ```

   - 腳本將自動：
     1. 建立/檢查 `~/redis_server/redis/logs/`、`~/redis_server/sentinel/redis-sentinel/` 等資料夾  
     2. 複製 `redis.conf`、`sentinel.conf` (若路徑存在)  
     3. 啟動容器：  
        - `redis-stack` (預設對外 `6379`, `8001`)  
        - `redis-sentinel` (以 `--net host` 方式啟動)  
     4. 設定每日 3 點自動執行 logrotate  
   - **多機 / 多容器注意事項**：  
     1. 每台機器都要執行類似的布署流程，並在 `redis.conf` 裡調整 `port`、`replicaof` (若是 Replica)，或修改 sentinel.conf 裡的 `sentinel monitor mymaster <master_ip> <port> <quorum>`。  
     2. 建議至少 3 台機器 / 3 個 Sentinel (quorum ≥ 2)，才具備高可用。  
     3. 若要重複部署、砍掉重建，將腳本內 `REMOVE_OLD_CONTAINERS="true"` 後再執行。

3. **驗證部署**  
   - 在每台機器上，檢查容器是否啟動：

     ```bash
     docker ps
     # 應該會看到 redis-stack, redis-sentinel 兩個容器
     ```

   - 檢查日誌：

     ```bash
     docker logs redis-stack
     docker logs redis-sentinel
     ```

   - 測試連線：

     ```bash
     redis-cli -p 6379 ping
     # 預期回傳 PONG (表示 Master 可用)
     ```

   - **多機下**，也可在任一 Sentinel 容器上查看監控狀態：

     ```bash
     # 假設 sentinel 佈署在 host 網路、使用 26379 埠
     redis-cli -p 26379 sentinel masters
     redis-cli -p 26379 sentinel slaves mymaster
     ```

   - 當 Master 宕機時，Sentinel(們) 應該可選出新的主節點 (前提是至少 3 個 Sentinel + 至少 1 個 Replica 節點)。

---

## 常見操作 (單機版)

1. **查看 Redis-stack 狀態**  

   ```bash
   docker ps
   docker logs redis-stack
   ```

2. **重啟服務**  
   - **快速重啟容器**:

     ```bash
     docker restart redis-stack
     ```

   - **重新部署**：  
     1. 先將 `deploy_single_redis_stack.sh` 內 `REMOVE_OLD_CONTAINER="true"`  
     2. 再次執行 `./deploy_single_redis_stack.sh`  
     > 會先刪除舊容器再建立新的容器
3. **修改參數**  
   - **maxmemory**：預設值在腳本 `REDIS_ARGS` 中可調整 `--maxmemory 12884901888` (約 12GB)。可改小，如 `--maxmemory 1073741824` (1GB)。  
   - **sentinel**：若不需要 sentinel，可把 `--sentinel` 移除。  
   - **埠號**：調整 `-p` 參數；如只需要 6379 和 8001，而不啟用 26379。  
4. **log 檔位置**  
   - 預設映射 `logs/` 資料夾，檔名 `log_redis-server.log`。可依需求改路徑或檔名。

---

## Sentinel 版本延伸

若要在 **非單機** 情境 (多 Redis 節點) 下使用 Sentinel 模式，建議再進行以下調整：

1. **Master/Slave 設定**  
   - 預設容器若加上 `--sentinel`，只能在本機啟動一個 Sentinel，仍需要至少**3 台**或**3 個容器**的哨兵实例來達成高可用 (quorum > 1)。  
   - 在 Redis.conf 或 `REDIS_ARGS` 中指定 `--replicaof <MASTER_IP> <PORT>` (6.x 以前是 `--slaveof`) 來設定從節點連線主節點。  
2. **指派 IP**  
   - 若要 Master/Slave/哨兵在不同機器上協同工作，需設定對外可連線的 IP 或網路介面 (可參考 Docker `--net` 參數或 docker-compose)；並在 `sentinel.conf` 內 `sentinel monitor mymaster <MASTER_IP> <PORT> <QUORUM>` 等設定。  
3. **多容器的 Docker-compose**  
   - 建議使用 docker-compose 或 K8s/Swarm 來部署多節點 Redis + Sentinel，以利設定網路、映射埠、環境變數等。  
4. **參考指令**  
   - Sentinel 常見指令：  

     ```bash
     redis-cli -p 26379 sentinel masters
     redis-cli -p 26379 sentinel slaves mymaster
     redis-cli -p 26379 sentinel failover mymaster
     ```

     (需根據實際名稱 `mymaster`、埠號等做調整)

---

## 故障排除

1. **容器無法啟動**  
   - `docker logs redis-stack` 查看日誌是否有無法解析命令或埠衝突  
   - 檢查本機埠是否已被佔用：`sudo lsof -i:6379`  
2. **記憶體不足**  
   - 如果 Redis 報錯 `OOM command not allowed when used memory > 'maxmemory'`，可增加 `--maxmemory` 或清除資料  
3. **無法連線**  
   - 檢查 `docker ps` 是否在執行  
   - 確認對外埠口 6379 (或 8001, 26379) 未被防火牆阻擋  
4. **Sentinel 不正常**  
   - 雙節點或單節點的 sentinel 通常無法提供可靠的故障切換  
   - 若要高可用，建議至少三個哨兵進行互相監控

---

## 結語

本說明檔提供 **單機版** 以及 **Sentinel 簡易延伸** 的部署與操作方式。  

- 若僅需單機版存取：使用 `deploy_single_redis_stack.sh` 並無需調整 `--sentinel`  
- 若需高可用：請研究多台部署 + sentinel 設定檔(或 docker-compose)  
如有進一步需求或故障排除，請聯繫相關維運人員或參考 [Redis 官方文件](https://redis.io/docs/latest/operate/oss_and_stack/)。  

---
