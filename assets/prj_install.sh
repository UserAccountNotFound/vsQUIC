#!/bin/bash

#
# Cкрипт установки и настройки окружения необходимого для демонстрации проекта
#

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Размер прогресс-бара (в символах)
BAR_WIDTH=20
# Общее количество шагов
TOTAL_STEPS=10
CURRENT_STEP=0

# Функция для отображения прогресса
progress-bar() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    FILLED=$((BAR_WIDTH * CURRENT_STEP / TOTAL_STEPS))
    EMPTY=$((BAR_WIDTH - FILLED))

    # Создаем строку прогресса
    BAR="["
    if [ $FILLED -gt 0 ]; then
        BAR+=$(printf "%0.s=" $(seq 1 $FILLED))
    fi
    if [ $EMPTY -gt 0 ]; then
        BAR+=$(printf "%0.s " $(seq 1 $EMPTY))
    fi
    BAR+="]"

    # Выводим в той же строке
    echo -ne "\r${BLUE}${BAR} ${PERCENT}% ${GREEN}$1${NC}"

    # Если завершено, перевести строку
    if [ $CURRENT_STEP -eq $TOTAL_STEPS ]; then
        echo
    fi
}

# Функция для обработки ошибок
error_exit() {
    echo -e "\n${RED}Ошибка на шаге [${PERCENT}%]: $1${NC}"
    exit 1
}

# Проверка и обновление репозитория vsQUIC
check-update_repo() {
    local repo_dir="/opt/vsQUIC"
    if [ -d "$repo_dir/.git" ]; then
        echo -e "${YELLOW}Обнаружен существующий репозиторий vsQUIC. Обновляю...${NC}"
        cd "$repo_dir" || return 1
        git pull origin main || return 1    # main - ветка репозитория с которой работаем 
        cd - >/dev/null || return 1
    else
        # Если папка существует, но это не git репозиторий
        if [ -d "$repo_dir" ]; then
            echo -e "${YELLOW}Папка vsQUIC существует, но не является git репозиторием. Удаляю...${NC}"
            rm -rf "$repo_dir" || return 1
        fi
        # Клонируем репозиторий
        echo -e "${YELLOW}Клонирую репозиторий vsQUIC...${NC}"
        git clone https://github.com/UserAccountNotFound/vsQUIC.git "$repo_dir" || return 1
    fi
    return 0
}

# Проверка и очистка окружения
clean_env() {
    local cert_dir="/opt/vsQUIC/server/cert"
    if [ -d "$cert_dir" ]; then
        rm -f "${cert_dir}/key-srv.pem" "${cert_dir}/cert-srv.pem" 2>/dev/null
    else
        mkdir -p "$cert_dir" || error_exit "Не удалось создать директорию для сертификатов"
    fi
}

# Выводим пустую строку перед началом
echo

# Установка локалей и настройка времени
progress-bar "Настройка локалей и времени"
apt update -q >/dev/null || error_exit "Ошибка обновления базы пакетов операционной системы"
apt install locales -y || error_exit "Ошибка установки пакета локалей"
timedatectl set-timezone Europe/Moscow || error_exit "Ошибка установки часового пояса"
sed -i -e 's/# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen || error_exit "Ошибка настройки локали"
locale-gen ru_RU.UTF-8 || error_exit "Ошибка генерации локали RU.UTF-8"
update-locale LANG=ru_RU.UTF-8 || error_exit "Ошибка установки локали RU.UTF-8 по умолчанию"

# Установка Docker и зависимостей
progress-bar "Установка необходимых базовых пакетов"
apt install -qy ca-certificates \
                curl \
                gnupg \
                sudo \
                mc \
                git \
                net-tools \
                openssl || error_exit "Ошибка установки базовых пакетов"

progress-bar "Настройка репозитория Docker"
install -m 0755 -d /etc/apt/keyrings || error_exit "Ошибка создания директории"
curl -fsSL https://download.docker.com/linux/debian/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg || error_exit "Ошибка загрузки ключа репозитория Docker"
chmod a+r /etc/apt/keyrings/docker.gpg || error_exit "Ошибка установки прав на добавленый ключь репозитория Docker"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || error_exit "Ошибка добавления репозитория Docker"

progress-bar "Установка Docker"
apt update -q >/dev/null || error_exit "Ошибка обновления базы пакетов операционной системы"
apt install -y docker-ce \
               docker-ce-cli \
               containerd.io \
               docker-buildx-plugin \
               docker-compose-plugin || error_exit "Ошибка установки пакетов Docker"
apt upgrade -y || error_exit "Ошибка обновления системы"

progress-bar "Проверка репозитория vsQUIC"
check-update_repo || error_exit "Ошибка при работе с репозиторием vsQUIC"

progress-bar "Очистка устаревшего окружения"
clean_env || error_exit "Ошибка при работе с репозиторием vsQUIC"

# Генерация сертификата
progress-bar "Генерация сертификата"
openssl req -x509 -newkey rsa:4096 \
    -keyout /opt/vsQUIC/server/cert/key-srv.pem \
    -out /opt/vsQUIC/server/cert/cert-srv.pem \
    -days 365 -nodes \
    -subj "/CN=VulnerableQuicServer" >/dev/null 2>&1 || error_exit "Ошибка генерации сертификата"

# Запуск Docker-контейнеров
progress-bar "Запуск Docker-контейнеров"
cd /opt/vsQUIC || error_exit "Ошибка перехода в директорию проекта"
docker compose down && docker compose up -d || error_exit "Ошибка запуска контейнеров"

# Финальное сообщение
echo -e "${GREEN}\nУстановка завершена на 100%!${NC}"
echo -e "${YELLOW}Для просмотра логов контейнеров выполните:${NC}"
echo -e "docker compose logs -f\n"
