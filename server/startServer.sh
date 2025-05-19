#!/usr/bin/env bash

# версия запускаемой реализации QUIC-SERVER_XXXX.py
VERSION="v1.3"

# маркеры для отслеживания выполненных установок
INSTALL_SYS_PKG_STATUS="/opt/ENV/.sys_pkg_install_done"
INSTALL_ENV_PKG_STATUS="/opt/ENV/.env_pkg_install_done"

# Функция для проверки и установки Python
install_or_update_python() {
    if ! command -v python3 &> /dev/null; then
        echo "Python не найден. Установка Python 3..."
        apt update && apt install -y python3
    else
        echo "Python уже установлен."
    fi
}

# Функция для проверки и установки pip
install_or_update_pip() {
    if ! command -v pip3 &> /dev/null; then
        echo "pip3 не найден. Установка pip..."
        apt install -y python3-pip
    else
        echo "pip3 уже установлен. Обновление pip..."
        pip3 install --upgrade pip
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
    install_or_update_pip
    
    # Создаем файл-маркер
    touch "$INSTALL_SYS_PKG_STATUS"
    echo "Первоначальная установка завершена"
fi

echo "Инициализация виртуального окружения..."
init_venv

# Проверка, была ли уже выполнена установка пакетов окружения
if [ ! -f "$INSTALL_ENV_PKG_STATUS" ]; then
    echo "Установка зависимостей из requirements.txt..."
    pip3 install -r /opt/requirements.txt
    
    # Создаем файл-маркер
    touch "$INSTALL_ENV_PKG_STATUS"
    echo "Первоначальная установка завершена"
fi

echo "Запуск QUIC сервера..."
python3 /opt/quic-srv_"$VERSION".py

deactivate
