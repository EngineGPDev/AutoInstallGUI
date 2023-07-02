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

    # Версия PHP
    php_ver="8.1"

    # Список пакетов #1 для установки
    packages_one=(lsb-release software-properties-common net-tools curl ufw memcached zip unzip bc)
    
    # Список пакетов #2 для установки
    packages_two=(php$php_ver php$php_ver-common php$php_ver-cli php$php_ver-memcache php$php_ver-memcached php$php_ver-mysqli php$php_ver-xml php$php_ver-mbstring php$php_ver-gd php$php_ver-gd2 php$php_ver-imagick php$php_ver-zip php$php_ver-curl php$php_ver-ssh2 php$php_ver-xml php$php_ver-fpm apache2 apache2-utils nginx mariadb-server)
    
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

        root /var/enginegp;
        charset utf-8;

        access_log /var/log/enginegp/nginx_enginegp_access.log combined buffer=64k;
        error_log /var/log/enginegp/nginx_enginegp_error.log error;

        index index.php index.htm index.html;
        
        location / {
            proxy_pass http://127.0.0.1:8080;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$remote_addr;
            proxy_connect_timeout 120;
            proxy_send_timeout 120;
            proxy_read_timeout 180;
        }

        location ~* \.(gif|jpeg|jpg|txt|png|tif|tiff|ico|jng|bmp|doc|pdf|rtf|xls|ppt|rar|rpm|swf|zip|bin|exe|dll|deb|cur)$ {
            access_log off;
            expires 3d;
        }

        location ~* \.(css|js)$ {
            access_log off;
            expires 180m;
        }

        location ~ /\.ht {
            deny all;
        }
    }
    "

    # Цикл по списку пакетов
    for package in "${packages[@]}"
    do
        # Проверяем установку
        if ! command -v php && command -v curl >> "$(dirname "$0")/enginegp_install.log"; then
            if [ $count -ge 10 ]; then
                # Добавляем репозиторий php
                sudo curl -sSL https://packages.sury.org/php/README.txt | sudo bash -x >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Обновление таблиц
                apt-get update -y >> "$(dirname "$0")/enginegp_install.log" 2>&1
            fi
        fi

        # Установка пакета
        sudo apt-get install $package -y >> "$(dirname "$0")/enginegp_install.log" 2>&1

        # Проверяем установку apache
        if command -v apache2 >> "$(dirname "$0")/enginegp_install.log" 2>&1; then
            if [ ! -f /etc/apache2/sites-available/enginegp.conf ]; then
                # Разрешаем доступ к портам
                sudo ufw allow 80 >> "$(dirname "$0")/enginegp_install.log" 2>&1
                sudo ufw allow 443 >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Изменяем порт, на котором слушает Apache
                echo -e "$apache_ports" | sudo tee /etc/apache2/ports.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Создаём папку для записи логов, если ещё не создана
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

                # Включаем PHP-FPM по умолчанию
                sudo a2enmod proxy_fcgi setenvif >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Включаем PHP-FPM в apache2
                sudo a2enconf php$php_ver-fpm >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Перезапускаем apache
                sudo systemctl restart apache2 >> "$(dirname "$0")/enginegp_install.log" 2>&1
            fi
        fi

        # Проверяем установку nginx
        if command -v nginx >> "$(dirname "$0")/enginegp_install.log" 2>&1; then
            if [ ! -f /etc/nginx/sites-available/enginegp.conf ]; then
                # Создаём папку для записи логов, если ещё не создана
                sudo mkdir /var/log/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1

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

        : '
        # Устанавливаем phpMyAdmin
        if command -v mysql >> "$(dirname "$0")/enginegp_install.log" 2>&1; then

        fi
        '

        # Устанавливаем панель
        if [ ! -d /var/enginegp/ ]; then
            if command -v curl && command -v unzip && command -v php >> "$(dirname "$0")/enginegp_install.log" 2>&1; then
                # Закачиваем и распаковываем панель
                sudo curl -sSL -o /var/enginegp.zip $enginegp_url >> "$(dirname "$0")/enginegp_install.log" 2>&1
                sudo unzip /var/enginegp.zip -d /var/ >> "$(dirname "$0")/enginegp_install.log" 2>&1
                sudo mv /var/EngineGP-* /var/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1
                sudo rm /var/enginegp.zip >> "$(dirname "$0")/enginegp_install.log" 2>&1
                
                # Задаём права на каталог
                chown www-data:www-data -R /var/enginegp/ >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Установка и настрока composer
                curl -o composer-setup.php https://getcomposer.org/installer >> "$(dirname "$0")/enginegp_install.log" 2>&1
                php composer-setup.php --install-dir=/usr/local/bin --filename=composer >> "$(dirname "$0")/enginegp_install.log" 2>&1
                cd /var/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1
                sudo composer install --no-interaction >> "$(dirname "$0")/enginegp_install.log" 2>&1
                cd >> "$(dirname "$0")/enginegp_install.log" 2>&1
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