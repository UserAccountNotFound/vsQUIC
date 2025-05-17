#!/usr/bin/env bash

#
# Кросс-дистрибутивный скрипт установки и настройки окружения для демонстрации проекта
#

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Настройки репозитория
REPO_URL="https://github.com/UserAccountNotFound/vsQUIC.git"
REPO_BRANCH="dev"  # Указываем нужную ветку репозитория
DESTINATION_DIR="/opt/vsQUIC"

# Размер прогресс-бара (в символах)
BAR_WIDTH=20
# Общее количество шагов
TOTAL_STEPS=10
CURRENT_STEP=0

# Определение дистрибутива и менеджера пакетов
detect_package_manager() {
    if command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

PKG_MANAGER=$(detect_package_manager)

# Функция для установки пакетов
install_packages() {
    local packages=("$@")
    case $PKG_MANAGER in
        apt)
            apt install -y "${packages[@]}" || return 1
            ;;
        yum)
            yum install -y "${packages[@]}" || return 1
            ;;
        dnf)
            dnf install -y "${packages[@]}" || return 1
            ;;
        zypper)
            zypper -n install "${packages[@]}" || return 1
            ;;
        pacman)
            pacman -S --noconfirm "${packages[@]}" || return 1
            ;;
        *)
            echo -e "${RED}Неизвестный менеджер пакетов${NC}"
            return 1
            ;;
    esac
    return 0
}

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
    if [ -d "$DESTINATION_DIR/.git" ]; then
        echo -e "${YELLOW}Обнаружен существующий репозиторий vsQUIC. Обновляю...${NC}"
        cd "$DESTINATION_DIR" || return 1
        git checkout "$REPO_BRANCH" || return 1
        git pull origin "$REPO_BRANCH" || return 1
        cd - >/dev/null || return 1
    else
        # Если папка существует, но это не git репозиторий
        if [ -d "$DESTINATION_DIR" ]; then
            echo -e "${YELLOW}Папка vsQUIC существует, но не является git репозиторием. Удаляю...${NC}"
            rm -rf "$DESTINATION_DIR" || return 1
        fi
        # Клонируем репозиторий
        echo -e "${YELLOW}Клонирую репозиторий vsQUIC (ветка $REPO_BRANCH)...${NC}"
        git clone -b "$REPO_BRANCH" "$REPO_URL" "$DESTINATION_DIR" || return 1
    fi
    return 0
}

# Проверка и очистка окружения
clean_env() {
    local cert_dir="$DESTINATION_DIR/server/cert"
    if [ -d "$cert_dir" ]; then
        rm -f "${cert_dir}/key-srv.pem" "${cert_dir}/cert-srv.pem" 2>/dev/null
    else
        mkdir -p "$cert_dir" || error_exit "Не удалось создать директорию для сертификатов"
    fi
}

# Установка Docker в зависимости от дистрибутива
install_docker() {
    case $PKG_MANAGER in
        apt)
            # Для Debian/Ubuntu
            progress-bar "Настройка репозитория Docker"
            install -m 0755 -d /etc/apt/keyrings || return 1
            curl -fsSL https://download.docker.com/linux/debian/gpg | \
                gpg --dearmor -o /etc/apt/keyrings/docker.gpg || return 1
            chmod a+r /etc/apt/keyrings/docker.gpg || return 1
            
            # Определяем код имени версии для репозитория
            local codename
            if [ -f /etc/os-release ]; then
                codename=$(grep -oP 'VERSION_CODENAME=\K\w+' /etc/os-release || echo "bookworm")
            else
                codename="bookworm"
            fi
            
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
                https://download.docker.com/linux/debian ${codename} stable" | \
                tee /etc/apt/sources.list.d/docker.list > /dev/null || return 1
            
            apt update -q >/dev/null || return 1
            ;;
        yum|dnf)
            # Для RHEL/CentOS/Fedora
            yum install -y yum-utils || dnf install -y dnf-plugins-core || return 1
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || \
            dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo || return 1
            ;;
        zypper)
            # Для openSUSE
            zypper addrepo https://download.docker.com/linux/opensuse/docker-ce.repo || return 1
            ;;
        pacman)
            # Для Arch Linux
            pacman -S --noconfirm docker || return 1
            systemctl enable --now docker.service || return 1
            return 0  # Docker уже установлен, выходим
            ;;
        *)
            echo -e "${RED}Неизвестный менеджер пакетов${NC}"
            return 1
            ;;
    esac

    progress-bar "Установка Docker"
    local docker_packages=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
    install_packages "${docker_packages[@]}" || return 1
    
    # Запускаем Docker
    if ! systemctl is-active --quiet docker; then
        systemctl enable --now docker || return 1
    fi
    
    return 0
}

# Выводим пустую строку перед началом
echo

# Установка локалей и настройка времени
progress-bar "Настройка локалей и времени"
case $PKG_MANAGER in
    apt|yum|dnf|zypper)
        install_packages locales || error_exit "Ошибка установки пакета локалей"
        ;;
    pacman)
        install_packages glibc || error_exit "Ошибка установки glibc"
        ;;
esac

timedatectl set-timezone Europe/Moscow || error_exit "Ошибка установки часового пояса"
sed -i -e 's/# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen || \
    error_exit "Ошибка настройки локали"
locale-gen ru_RU.UTF-8 || error_exit "Ошибка генерации локали RU.UTF-8"
update-locale LANG=ru_RU.UTF-8 || error_exit "Ошибка установки локали RU.UTF-8 по умолчанию"

# Установка базовых пакетов
progress-bar "Установка необходимых базовых пакетов"
base_packages=(ca-certificates curl gnupg sudo mc git net-tools openssl)
install_packages "${base_packages[@]}" || error_exit "Ошибка установки базовых пакетов"

# Установка Docker
install_docker || error_exit "Ошибка установки Docker"

progress-bar "Обновление системы"
case $PKG_MANAGER in
    apt) apt upgrade -y || error_exit "Ошибка обновления системы" ;;
    yum|dnf) $PKG_MANAGER update -y || error_exit "Ошибка обновления системы" ;;
    zypper) zypper -n up || error_exit "Ошибка обновления системы" ;;
    pacman) pacman -Syu --noconfirm || error_exit "Ошибка обновления системы" ;;
esac

progress-bar "Проверка репозитория vsQUIC"
check-update_repo || error_exit "Ошибка при работе с репозиторием vsQUIC"

progress-bar "Очистка устаревшего окружения"
clean_env || error_exit "Ошибка при работе с репозиторием vsQUIC"

# Генерация сертификата
progress-bar "Генерация сертификата"
openssl req -x509 -newkey rsa:4096 \
    -keyout "$DESTINATION_DIR/server/cert/key-srv.pem" \
    -out "$DESTINATION_DIR/server/cert/cert-srv.pem" \
    -days 365 -nodes \
    -subj "/CN=VulnerableQuicServer" >/dev/null 2>&1 || error_exit "Ошибка генерации сертификата"

# Запуск Docker-контейнеров
progress-bar "Запуск Docker-контейнеров"
cd "$DESTINATION_DIR" || error_exit "Ошибка перехода в директорию проекта"
docker compose down && docker compose up -d || error_exit "Ошибка запуска контейнеров"

# Финальное сообщение
echo -e "${GREEN}\nУстановка завершена на 100%!${NC}"
echo -e "${YELLOW}Для просмотра логов контейнеров выполните:${NC}"
echo -e "docker compose logs -f\n"