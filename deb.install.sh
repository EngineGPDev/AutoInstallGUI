#!/bin/bash
# Определение операционной системы
osver=`cat /etc/issue.net | awk '{print $1,$3}'`

# Функция для установки пакетов
install_enginegp() {
    # Счетчик установленных пакетов
    count=0

    # Список пакетов #1 для установки
    packages_one=(ca-certificates apt-transport-https software-properties-common curl lsb-release ufw net-tools memcached zip unzip bc)
    
    # Список пакетов #2 для установки
    packages_two=(php8.1 php8.1-cli php8.1-memcache php8.1-mysqli php8.1-xml php8.1-mbstring php8.1-gd php8.1-imagick php8.1-zip php8.1-curl php8.1-ssh2 php8.1-xml php8.1-common apache2 apache2-utils)
    
    # Итоговый список пакетов для установки
    packages=( "${packages_one[@]}" "${packages_two[@]}" )

    # Цикл по списку пакетов
    for package in "${packages[@]}"
    do
        # Установка пакета
        sudo apt-get install $package -y >> "$(dirname "$0")/enginegp_install.log" 2>&1

        # Общее количество пакетов
        total=${#packages[@]}

        # Увеличение счетчика
        count=$((count+1))

        # Вычисление процента выполнения
        percent=$((count*100/total))

        # Отображение прогресс бара
        echo "XXX"
        echo "Installing $package ($count of $total)"
        echo "XXX"
        echo $percent
    done | dialog --title "Installing EngineGP" --gauge "Start of installation" 10 70 0
}

# Функция для настройки локации
setting_location() {
    echo "Success"
}

# Функция для скачивания игр
download_games() {
    echo "Success"
}

# Функция главного меню
menu() {
    option=$(whiptail --title  "EngineGP Installation Menu" --menu  "Current OS version: $osver\nLatest version of EngineGP: v4.0.0-beta.3\n \nSelect an item from the list" 10 70 0 \
    "1." "Install EngineGP" \
    "2." "Setting up a location" \
    "3." "Downloading games" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 0 ];  then
        if [ "$option" = "1." ]; then
            install_enginegp
        elif [ "$option" = "2." ]; then
            setting_location
        elif [ "$option" = "3." ]; then
            download_games
        fi
    else
        clear
        echo "EngineGP installation aborted."
    fi
}

menu