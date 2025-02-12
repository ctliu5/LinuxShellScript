#!/bin/bash

# 一鍵安裝 Docker 腳本（適用於 Debian）
set -e

# 移除可能衝突的套件
echo "Removing conflicting packages..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y $pkg || true
done

# 更新系統套件列表
echo "Updating package lists..."
sudo apt update -y

# 安裝必要的工具
echo "Installing prerequisites..."
sudo apt-get install -y ca-certificates curl gnupg

# 添加 Docker 官方 GPG 金鑰
echo "Adding Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 添加 Docker 官方 APT 存儲庫
echo "Adding Docker APT repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新系統套件列表
echo "Updating package lists again..."
sudo apt update -y

# 安裝 Docker 和相關套件
echo "Installing Docker..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 啟動並啟用 Docker 服務
echo "Enabling and starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# 測試 Docker 安裝
echo "Testing Docker installation..."
sudo docker run hello-world || echo "Docker test failed. Please check the installation."

# 建立 docker 群組 
echo "Creating Docker group..." 
sudo groupadd docker || true 

# 提示用戶需要手動將自己加入 docker 群組
echo "Important: To use Docker without sudo, you need to add your user to the docker group."
echo "Please run this command manually: sudo usermod -aG docker \$USER"
echo "After running the command, log out and log back in or restart your system for the changes to take effect."
