#!/bin/bash
# Установка необходимых пакетоа
apt install sudo whiptail dialog -y

# Делаем файл "deb.install.sh" исполняемым и запускаем
chmod +x deb.install.sh && ./deb.install.sh