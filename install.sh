#!/bin/bash
# Очистка экрана перед установкой
clear

echo "
[EN] Preparing the server for automatic configuration.
[RU] Подготовка сервера к автоматической настройке.
"

# Обновление таблиц
apt-get update -y >> "$(dirname "$0")/enginegp_install.log" 2>&1

# Обновление пакетов
apt-get upgrade -y >> "$(dirname "$0")/enginegp_install.log" 2>&1

# Установка необходимых пакетоа
apt-get install sudo whiptail dialog dos2unix -y >> "$(dirname "$0")/enginegp_install.log" 2>&1

# Преобразование установщика в unix
dos2unix deb.install.sh >> "$(dirname "$0")/enginegp_install.log" 2>&1

# Делаем файл "deb.install.sh" исполняемым и запускаем
chmod +x deb.install.sh && ./deb.install.sh