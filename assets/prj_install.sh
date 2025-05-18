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
REPO_BRANCH="main"  # Указываем нужную ветку репозитория
DESTINATION_DIR="/opt/vsQUIC"

# Размер прогресс-бара (в символах)
BAR_WIDTH=20
# Общее количество шагов
TOTAL_STEPS=10
CURRENT_STEP=0

# Функция определения дистрибутива и менеджера пакетов
detect_distrib() {
    local linux_distrib=""
    local version_codename=""
    local pkg_manager=""

    # Определяем используемый дистрибутив linux и его версию
    if [ -f /etc/os-release ]; then
        linux_distrib=$(grep -oP '^ID=\K\w+' /etc/os-release | tr -d '"')
        version_codename=$(grep -oP 'VERSION_CODENAME=\K\w+' /etc/os-release 2>/dev/null || echo "")
    fi

    # Определяем менеджер пакетов
    if command -v apt >/dev/null 2>&1; then
        pkg_manager="apt"
        [ -z "$version_codename" ] && version_codename="bookworm" # Значение по умолчанию для Debian
    elif command -v dnf >/dev/null 2>&1; then
        pkg_manager="dnf"
    elif command -v yum >/dev/null 2>&1; then
        pkg_manager="yum"
    elif command -v zypper >/dev/null 2>&1; then
        pkg_manager="zypper"
    elif command -v pacman >/dev/null 2>&1; then
        pkg_manager="pacman"
    else
        pkg_manager="unknown"
    fi

    echo "$linux_distrib $pkg_manager $version_codename"
}

# Получаем информацию о дистрибутиве
read -r LINUX_DISTRIB PKG_MANAGER VERSION_CODENAME <<<"$(detect_distrib)"

# Функция для установки пакетов
install_packages() {
    local packages=("$@")
    case $PKG_MANAGER in
    apt)
        DEBIAN_FRONTEND=noninteractive apt-get -qq install -y "${packages[@]}" || return 1
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
    echo -ne "\r${BLUE}${BAR} ${PERCENT}% ${GREEN}$1${NC}\n"

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
        git stash || return 1  # Сохраняем локальные изменения
        git pull origin "$REPO_BRANCH" || return 1
        cd - >/dev/null || return 1
    else
        # Если папка существует, но это не git репозиторий
        if [ -d "$DESTINATION_DIR" ]; then
            echo -e "${YELLOW}Папка vsQUIC существует, но не является git репозиторием. Удаляем...${NC}"
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
    # Удаление флагов установки пакетов, старых сертификатов
    local env_dirs=(
        "${DESTINATION_DIR}/client/ENV"
        "${DESTINATION_DIR}/server/ENV"
    )

    # Создаем директории для хранения переменных, если её нет (с проверкой прав)
    for dir in "${env_dirs[@]}"; do
        if ! mkdir -p "$dir" 2>/dev/null; then
            error_exit "Не удалось создать директорию для хранения переменных: $dir"
        fi
    done

    # Удаляем хранимые переменные, сертификаты, и т.д., если они существуют
    for dir in "${env_dirs[@]}"; do
        if [ -d "$dir" ]; then
            for file in ".sys_pkg_install_done" \
                        ".env_pkg_install_done" \
                        ".key-srv.pem" \
                        ".cert-srv.pem"; \
                     do
                if [ -f "${dir}/$file" ] && [ ! -w "${dir}/$file" ]; then
                    rm -f "${dir}/$file" || echo -e "${YELLOW}Не удалось удалить ${dir}/$file - недостаточно прав${NC}"
                elif [ -f "${dir}/$file" ]; then
                    rm -f "${dir}/$file"
                fi
            done
        fi
    done
}

# Установка Docker в зависимости от дистрибутива
install_docker() {
    case $PKG_MANAGER in
    apt)
        # Для Debian/Ubuntu
        progress-bar "Настройка репозитория Docker"
        install -m 0755 -d /etc/apt/keyrings || return 1
        curl -fsSL https://download.docker.com/linux/$LINUX_DISTRIB/gpg |
            gpg --dearmor -o /etc/apt/keyrings/docker.gpg || return 1
        chmod a+r /etc/apt/keyrings/docker.gpg || return 1

        # Для Ubuntu используем ubuntu вместо debian в URL
        local docker_repo_distro=$([ "$LINUX_DISTRIB" = "ubuntu" ] && echo "ubuntu" || echo "debian")

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
                https://download.docker.com/linux/$docker_repo_distro $VERSION_CODENAME stable" |
            tee /etc/apt/sources.list.d/docker.list >/dev/null || return 1

        apt-get update -qq >/dev/null || return 1
        ;;
    yum | dnf)
        # Для RHEL/CentOS/Fedora
        $PKG_MANAGER install -y yum-utils || $PKG_MANAGER install -y dnf-plugins-core || return 1
        $PKG_MANAGER config-manager --add-repo \
            https://download.docker.com/linux/centos/docker-ce.repo || return 1
        ;;
    zypper)
        # Для openSUSE
        zypper addrepo https://download.docker.com/linux/opensuse/docker-ce.repo || return 1
        ;;
    pacman)
        # Для Arch Linux
        pacman -S --noconfirm docker || return 1
        systemctl enable --now docker.service || return 1
        return 0 # Docker уже установлен, выходим
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
apt | yum | dnf | zypper)
    install_packages locales || error_exit "Ошибка установки пакета локалей"
    ;;
pacman)
    install_packages glibc || error_exit "Ошибка установки glibc"
    ;;
esac

timedatectl set-timezone Europe/Moscow || error_exit "Ошибка установки часового пояса"
sed -i -e 's/# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen ||
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
apt) DEBIAN_FRONTEND=noninteractive apt-get -qq -y upgrade >/dev/null || error_exit "Ошибка обновления системы" ;;
yum | dnf) $PKG_MANAGER update -y || error_exit "Ошибка обновления системы" ;;
zypper) zypper -n up || error_exit "Ошибка обновления системы" ;;
pacman) pacman -Syu --noconfirm || error_exit "Ошибка обновления системы" ;;
esac

progress-bar "Проверка репозитория vsQUIC"
check-update_repo || error_exit "Ошибка при обновлении репозитория vsQUIC"

progress-bar "Очистка устаревшего окружения"
clean_env || error_exit "Ошибка при очистке окружения"

# Генерация сертификата
progress-bar "Генерация сертификата"
openssl req -x509 -newkey rsa:4096 \
    -keyout "$DESTINATION_DIR/server/ENV/key-srv.pem" \
    -out "$DESTINATION_DIR/server/ENV/cert-srv.pem" \
    -days 365 -nodes \
    -subj "/CN=VulnerableQuicServer" >/dev/null 2>&1 || error_exit "Ошибка генерации сертификата"

# Запуск Docker-контейнеров
progress-bar "Запуск Docker-контейнеров"
cd "$DESTINATION_DIR" || error_exit "Ошибка перехода в директорию проекта"
docker compose down && docker compose up -d || error_exit "Ошибка запуска контейнеров"

# Финальное сообщение
echo -e "${GREEN}\nУстановка завершена на 100%!${NC}"
echo -e "${YELLOW}Для перехода в рабочую папку проекта (стенда) выполните:${NC}"
echo -e "cd /opt/vsQUIC\n"
echo -e "${YELLOW}Для просмотра логов контейнеров выполните:${NC}"
echo -e "docker compose logs -f\n"