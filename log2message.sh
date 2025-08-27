#!/bin/bash

# Загружаем конфиг
CONFIG_FILE="/etc/log2http.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] Config file not found: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

# Создаём каталог для offset'ов
mkdir -p "$OFFSET_DIR"

send_to_url() {
    local log_name="$1"
    local msg="$2"
    curl -s -X POST "$POST_URL" \
         -H "Content-Type: application/json" \
         -d "{\"log\":\"$log_name\",\"message\":\"$msg\"}" >/dev/null
}

read_offset() {
    local log_file="$1"
    local ofs_file="${OFFSET_DIR}/$(basename "$log_file").offset"
    if [[ -f "$ofs_file" ]]; then
        cat "$ofs_file"
    else
        echo 0
    fi
}

write_offset() {
    local log_file="$1"
    local offset="$2"
    local ofs_file="${OFFSET_DIR}/$(basename "$log_file").offset"
    echo "$offset" > "$ofs_file"
}

process_log() {
    local log_file="$1"
    if [[ ! -f "$log_file" ]]; then
        echo "[WARN] Log file not found: $log_file"
        return
    fi

    local last_offset=$(read_offset "$log_file")
    local filesize=$(stat -c%s "$log_file")

    # Если logrotate обрезал файл
    if (( filesize < last_offset )); then
        last_offset=0
    fi

    # Читаем новые строки и шлём
    tail -c +$((last_offset+1)) "$log_file" | while IFS= read -r line; do
        [[ -n "$line" ]] && send_to_url "$(basename "$log_file")" "$line"
    done

    # Запоминаем новую позицию
    write_offset "$log_file" "$filesize"
}

# === Основной цикл ===
while true; do
    for log in $LOG_FILES; do
        process_log "$log"
    done
    sleep "$CHECK_INTERVAL"
done