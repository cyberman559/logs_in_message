#!/bin/bash
set -e

SRC_DIR="$(pwd)"

SCRIPT_SRC="./log2message.sh"               # путь к исходному скрипту
SCRIPT_DEST="/usr/local/bin/log2message.sh"
CONFIG_FILE="/etc/log2message.conf"
SERVICE_FILE="/etc/systemd/system/log2message.service"

# === Проверка существования основного скрипта ===
if [[ ! -f "$SCRIPT_SRC" ]]; then
    echo "[ERROR] Не найден основной скрипт $SCRIPT_SRC"
    echo "Поместите log2message.sh в ту же папку, что и установщик."
    exit 1
fi

# === Ввод параметров ===
read -p "Введите название проекта: "


read -p "Введите POST_URL (например https://example.com/logs): " POST_URL
read -p "Введите CHECK_INTERVAL [по умолчанию 600]: " CHECK_INTERVAL
CHECK_INTERVAL=${CHECK_INTERVAL:-600}

read -p "Введите LOG_FILES [по умолчанию /var/log/httpd/*error_log /var/log/mysql/error.log /var/log/nginx/*error_log /var/log/php/exceptions.log]: " LOG_FILES
LOG_FILES=${LOG_FILES:-"/var/log/httpd/*error_log /var/log/mysql/error.log /var/log/nginx/*error_log /var/log/php/exceptions.log"}

read -p "Введите OFFSET_DIR [по умолчанию /var/tmp/log2message]: " OFFSET_DIR
OFFSET_DIR=${OFFSET_DIR:-"/var/tmp/log2message"}

# === Копирование основного скрипта ===
echo "[INFO] Копируем $SCRIPT_SRC -> $SCRIPT_DEST"
cp "$SCRIPT_SRC" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"

# === Создание конфигурации ===
echo "[INFO] Создаём конфиг $CONFIG_FILE"
cat > "$CONFIG_FILE" <<EOF
# === log2message конфигурация ===
POST_URL="$POST_URL"
CHECK_INTERVAL=$CHECK_INTERVAL
LOG_FILES="$LOG_FILES"
OFFSET_DIR="$OFFSET_DIR"
EOF

# === Создание systemd unit ===
echo "[INFO] Создаём systemd unit $SERVICE_FILE"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Log to HTTP Forwarder (multi-file)
After=network.target

[Service]
ExecStart=$SCRIPT_DEST
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# === Активация и запуск сервиса ===
echo "[INFO] Перезапускаем systemd и включаем сервис"
systemctl daemon-reload
systemctl enable log2message
systemctl restart log2message

# === Удаляем исходную папку ===
echo "[INFO] Удаляем исходную папку $SRC_DIR"
cd /
rm -rf "$SRC_DIR"

echo "[SUCCESS] Установка завершена. Сервис log2message работает."
