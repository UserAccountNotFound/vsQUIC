#!/usr/bin/env bash

# версия запускаемой реализации QUIC-CLIENT_XXXX.py
VERSION="v2.5"

# маркеры для отслеживания выполненных установок
INSTALL_SYS_PKG_STATUS="/opt/ENV/.sys_pkg_install_done"
INSTALL_ENV_PKG_STATUS="/opt/ENV/.env_pkg_install_done"

# Функция для проверки и установки пакетов требуемых для работы и отладки
install_or_update_base_packages() {
    echo "Обновление базы системных пакетов"
    apt-get -qq update
    if ! command -V python3 &> /dev/null; then
        echo "Python не найден. Установка Python 3..."
        apt-get -qq install -y python3
    if ! command -V netstat &> /dev/null; then
        echo "netstat не найден. Установка net-tools..."
        apt-get -qq install -y net-tools
    if ! command -V pip3 &> /dev/null; then
        echo "pip3 не найден. Установка pip..."
        apt-get -qq install -y python3-pip    
    else
        echo "Все необходимые пакеты уже установлены..."
    fi
}

# Функция для создания виртуального окружения
init_venv() {
    local venv_path="/opt/venv"
    echo "Проверка виртуального окружения..."
    
    if [ ! -d "$venv_path" ]; then
        python3 -m venv "$venv_path"
        echo "Виртуальное окружение создано в $venv_path"
    else
        echo "Виртуальное окружение уже существует в $venv_path"
    fi
    
    echo "Активация виртуального окружения"
    source "$venv_path/bin/activate"
}

# Проверка, была ли уже выполнена установка системных пакетов
if [ ! -f "$INSTALL_SYS_PKG_STATUS" ]; then
    echo "Установка или обновление необходимых пакетов"
    install_or_update_python
    
    # Создаем файл-маркер
    touch "$INSTALL_SYS_PKG_STATUS"
    echo "Первоначальная установка завершена"
fi

echo "Инициализация виртуального окружения..."
init_venv

# Проверка, была ли уже выполнена установка пакетов окружения
if [ ! -f "$INSTALL_ENV_PKG_STATUS" ]; then
    echo "Попытка Обновление pip..."
    pip3 install --upgrade pip
    echo "Установка зависимостей из requirements.txt..."
    pip3 install -r /opt/requirements.txt
    
    # Создаем файл-маркер
    touch "$INSTALL_ENV_PKG_STATUS"
    echo "Первоначальная установка завершена"
fi

echo "Запуск QUIC клиента..."
python3 /opt/quic-client_"$VERSION".py

deactivate
