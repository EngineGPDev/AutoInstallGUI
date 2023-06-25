#!/bin/bash
# Очистка экрана перед установкой
clear

# Определение операционной системы
osver=`cat /etc/issue.net | awk '{print $1,$3}'`

# Определение IP адреса первым методом
ipaddr=$(echo "${SSH_CONNECTION}" | awk '{print $3}')

# Определение IP адреса вторым методом
if [ -z "$ipaddr" ]; then
    ipaddr=$(wget -qO- eth0.me)
fi

# Функция для установки пакетов
install_enginegp() {
    # Счетчик установленных пакетов
    count=0

    # Список пакетов #1 для установки
    packages_one=(lsb-release software-properties-common net-tools curl ufw memcached zip unzip bc)
    
    # Список пакетов #2 для установки
    packages_two=(php8.1 php8.1-cli php8.1-memcache php8.1-mysqli php8.1-xml php8.1-mbstring php8.1-gd php8.1-imagick php8.1-zip php8.1-curl php8.1-ssh2 php8.1-xml php8.1-common apache2 apache2-utils nginx)
    
    # Итоговый список пакетов для установки
    packages=( "${packages_one[@]}" "${packages_two[@]}" )

    # Версия EngineGP
    enginegp_ver="v4.0.0-beta.3"

    # Источник EngineGP
    enginegp_url="https://github.com/EngineGPDev/EngineGP/archive/refs/tags/$enginegp_ver.zip"

    # Конфигурация apache для заглушки
    apache_default="
    <VirtualHost *:8080>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html
        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined
    </VirtualHost>
    "

    apache_ports="
    Listen 8080

    <IfModule ssl_module>
        Listen 443
    </IfModule>

    <IfModule mod_gnutls.c>
     Listen 443
    </IfModule>
    "

    # Конфигурация apache для EngineGP
    apache_enginegp="
    <VirtualHost *:8080>
        ServerName $ipaddr
        DocumentRoot /var/enginegp
        ErrorLog /var/log/enginegp/apache_enginegp_error.log
        CustomLog /var/log/enginegp/apache_enginegp_access.log combined
        <Directory />
             Options FollowSymLinks
             AllowOverride All
        </Directory>
        <Directory /var/enginegp/>
             Options Indexes FollowSymLinks
             AllowOverride All
             Require all granted
        </Directory>
    </VirtualHost>
    "

    # Конфигурация nginx для EngineGP
    nginx_enginegp="
    server {
        listen 80;
        server_name $ipaddr;
        access_log /var/log/enginegp/nginx_enginegp_access.log combined buffer=64k;
        error_log /var/log/enginegp/nginx_enginegp_error.log error;
        location / {
        proxy_pass http://127.0.0.1:8080;
            proxy_set_header Host      \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
        location ~* ^.+.(js|css|png|jpg|jpeg|gif|ico|woff)$ {
            root        /var/enginegp;
            access_log  off;
            expires     max;
        }
        location = /robots.txt {
            root  /var/enginegp;
            allow all;
            log_not_found off;
            access_log off;
        }
    }
    "

    # Цикл по списку пакетов
    for package in "${packages[@]}"
    do
        # Проверяем установку
        if ! dpkg -l | grep -q php && if dpkg -l | grep -q curl; then
            if [ $count -ge 9 ]; then
                # Добавляем репозиторий php
                sudo curl -sSL https://packages.sury.org/php/README.txt | sudo bash -x >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Обновление таблиц
                apt-get update -y >> "$(dirname "$0")/enginegp_install.log" 2>&1
            fi
        fi

        # Установка пакета
        sudo apt-get install $package -y >> "$(dirname "$0")/enginegp_install.log" 2>&1

        # Проверяем установку apache
        if dpkg -l | grep -q apache2; then
            if [ ! -f /etc/apache2/sites-available/enginegp.conf ]; then
                # Разрешаем доступ к портам
                sudo ufw allow 80 >> "$(dirname "$0")/enginegp_install.log" 2>&1
                sudo ufw allow 443 >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Изменяем порт, на котором слушает Apache
                echo -e "$apache_ports" | sudo tee /etc/apache2/ports.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Создаём папку для записи логов
                sudo mkdir /var/log/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Перезапускаем Apache
                sudo systemctl restart apache2 >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Заворачиваем все остальные запросы к apache
                echo -e "$apache_default" | sudo tee /etc/apache2/sites-available/000-default.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Создаем виртуальный хостинг для EngineGP
                echo -e "$apache_enginegp" | sudo tee /etc/apache2/sites-available/enginegp.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Проверяем конфиг apache и выводим в логи
                sudo apachectl configtest >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Включаем конфигурацию
                sudo a2ensite enginegp.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Включаем rewrite
                sudo a2enmod rewrite >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Перезапускаем apache
                sudo systemctl restart apache2 >> "$(dirname "$0")/enginegp_install.log" 2>&1
            fi
        fi

        # Проверяем установку nginx
        if dpkg -l | grep -q nginx; then
            if [ ! -f /etc/nginx/sites-available/enginegp.conf ]; then
                # Создаем виртуальный хостинг для EngineGP
                echo -e "$nginx_enginegp" | sudo tee /etc/nginx/sites-available/enginegp.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Создаём симлинк конфига NGINX
                sudo ln -s /etc/nginx/sites-available/enginegp.conf /etc/nginx/sites-enabled/ >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Проверяем конфиг nginx и выводим в логи
                sudo nginx -t >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Перезапускаем nginx
                sudo systemctl restart nginx >> "$(dirname "$0")/enginegp_install.log" 2>&1
            fi
        fi

        # Устанавливаем панель
        if [ ! -d /var/enginegp/ ] && [ $count -ge 9 ]; then
            if dpkg -l | grep -q curl && dpkg -l | grep -q unzip; then
                # Закачиваем и распаковываем панель
                sudo curl -sSL -o /var/enginegp.zip $enginegp_url >> "$(dirname "$0")/enginegp_install.log" 2>&1
                sudo unzip /var/enginegp.zip -d /var/ >> "$(dirname "$0")/enginegp_install.log" 2>&1
                sudo mv /var/EngineGP-* /var/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1
                sudo rm /var/enginegp.zip >> "$(dirname "$0")/enginegp_install.log" 2>&1
            fi
        fi

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