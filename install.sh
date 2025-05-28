#!/bin/bash

# Цвет для ярко-фиолетового вывода
PMAGENTA="\033[1;35m"
NC="\033[0m"

WEB4STATIC_BIN="/usr/local/bin/web4static"

# Функция вывода списка команд
print_help() {
  echo -e "${PMAGENTA}Доступные команды:${NC}"
  echo -e "${PMAGENTA}  install - установить/переустановить${NC}"
  echo -e "${PMAGENTA}  remove  - удалить${NC}"
  echo -e "${PMAGENTA}  restart - перезапустить сервис${NC}"
  echo -e "${PMAGENTA}  stop    - остановить сервис${NC}"
  echo -e "${PMAGENTA}Пример: web4static install${NC}"
}

# Проверяем, если запуск через bash <(...) — и есть установленный скрипт
if [[ "$0" =~ ^/dev/fd/ ]]; then
  if [[ -f $WEB4STATIC_BIN ]]; then
    echo -e "${PMAGENTA}[INFO] Скрипт уже установлен.${NC}"
    print_help
    echo -ne "${PMAGENTA}Введите команду: ${NC}"
    read -r cmd
    exec $WEB4STATIC_BIN "$cmd"
    exit
  else
    echo -e "${PMAGENTA}[WELCOME] Добро пожаловать в Web4Static установщик!${NC}"
    echo -ne "${PMAGENTA}Установить веб-панель? [Y/n]: ${NC}"
    read -r answer
    answer=${answer,,} # к нижнему регистру
    if [[ "$answer" =~ ^(n|no)$ ]]; then
      echo -e "${PMAGENTA}[CANCEL] Установка отменена.${NC}"
      exit 0
    fi
    echo -e "${PMAGENTA}[INFO] Устанавливаем скрипт как web4static...${NC}"
    curl -sL https://raw.githubusercontent.com/Mendex777/web4static/refs/heads/for_sing-box/install.sh -o $WEB4STATIC_BIN
    chmod +x $WEB4STATIC_BIN
    echo -e "${PMAGENTA}[INFO] Запускаем установку веб-панели...${NC}"
    exec $WEB4STATIC_BIN install
    exit
  fi
fi

# Настройки
WEB4STATIC_DIR="/opt/web4static"
PORT=9096
SERVICE_NAME="web4static.service"

FILES=(
  "https://raw.githubusercontent.com/Mendex777/web4static/refs/heads/for_sing-box/files/ascii.txt"
  "https://raw.githubusercontent.com/Mendex777/web4static/refs/heads/for_sing-box/files/functions.php"
  "https://raw.githubusercontent.com/Mendex777/web4static/refs/heads/for_sing-box/files/icons.svg"
  "https://raw.githubusercontent.com/Mendex777/web4static/refs/heads/for_sing-box/files/manifest.json"
  "https://raw.githubusercontent.com/Mendex777/web4static/refs/heads/for_sing-box/files/script.js"
  "https://raw.githubusercontent.com/Mendex777/web4static/refs/heads/for_sing-box/files/styles.css"
  "https://raw.githubusercontent.com/Mendex777/web4static/refs/heads/for_sing-box/index.php"
  "https://raw.githubusercontent.com/Mendex777/web4static/refs/heads/for_sing-box/web4static.php"
)

ICONS=(
  "https://raw.githubusercontent.com/Mendex777/web4static/for_sing-box/icons/favicon.png"
  "https://raw.githubusercontent.com/Mendex777/web4static/for_sing-box/icons/apple-touch-icon.png"
)

install_requirements() {
  echo -e "${PMAGENTA}[INFO] Устанавливаем необходимые пакеты: curl, php-cgi${NC}"
  sudo apt update
  sudo apt install -y curl php-cgi
}

download_files() {
  echo -e "${PMAGENTA}[INFO] Скачиваем файлы в ${WEB4STATIC_DIR}${NC}"
  mkdir -p "${WEB4STATIC_DIR}/files" "${WEB4STATIC_DIR}/icons"

  for url in "${FILES[@]}"; do
    filename=$(basename "$url")
    if [[ "$filename" == "web4static.php" || "$filename" == "index.php" ]]; then
      dest="${WEB4STATIC_DIR}/${filename}"
    else
      dest="${WEB4STATIC_DIR}/files/${filename}"
    fi
    echo -e "${PMAGENTA}  → ${filename}${NC}"
    curl -sL "$url" -o "$dest"
  done

  echo -e "${PMAGENTA}[INFO] Скачиваем иконки в ${WEB4STATIC_DIR}/icons${NC}"
  for url in "${ICONS[@]}"; do
    filename=$(basename "$url")
    dest="${WEB4STATIC_DIR}/icons/${filename}"
    echo -e "${PMAGENTA}  → ${filename}${NC}"
    curl -sL "$url" -o "$dest"
  done
}

create_service() {
  echo -e "${PMAGENTA}[INFO] Создаём systemd-сервис ${SERVICE_NAME}${NC}"
  sudo tee /etc/systemd/system/${SERVICE_NAME} > /dev/null <<EOF
[Unit]
Description=Web4Static PHP Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/php -S 0.0.0.0:${PORT} -t ${WEB4STATIC_DIR}
Restart=on-failure
User=root
WorkingDirectory=${WEB4STATIC_DIR}

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable ${SERVICE_NAME}
}

start_service() {
  echo -e "${PMAGENTA}[INFO] Запуск сервиса ${SERVICE_NAME}${NC}"
  sudo systemctl start ${SERVICE_NAME}
}

stop_service() {
  echo -e "${PMAGENTA}[INFO] Остановка сервиса ${SERVICE_NAME}${NC}"
  sudo systemctl stop ${SERVICE_NAME}
}

remove_web4static() {
  echo -e "${PMAGENTA}[INFO] Останавливаем и удаляем сервис${NC}"
  sudo systemctl disable ${SERVICE_NAME} --now
  sudo rm -f /etc/systemd/system/${SERVICE_NAME}
  sudo systemctl daemon-reload

  echo -e "${PMAGENTA}[INFO] Удаляем файлы установки${NC}"
  sudo rm -rf "${WEB4STATIC_DIR}"
  sudo rm -f $WEB4STATIC_BIN
}

get_local_ip() {
  ip addr show scope global | awk '/inet / && $2 !~ /127\./ { sub("/.*","",$2); print $2; exit }'
}

install_web4static() {
  install_requirements
  download_files
  chmod +x "$0"
  ln -sf "$0" $WEB4STATIC_BIN

  create_service
  start_service

  local ip=$(get_local_ip)
  echo -e "${PMAGENTA}[SUCCESS] Установка завершена. Открой в браузере: http://${ip}:${PORT}/${NC}"
  echo
  print_help
}

case "$1" in
  install)
    install_web4static
    ;;
  remove)
    remove_web4static
    ;;
  restart)
    stop_service
    start_service
    ;;
  stop)
    stop_service
    ;;
  *)
    echo -e "\n${PMAGENTA}Использование: $0 {install|remove|restart|stop}${NC}\n"
    ;;
esac
