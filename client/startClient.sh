#!/usr/bin/env bash

# Функция для проверки и установки Python
install_or_update_python() {
    if ! command -v python3 &> /dev/null; then
        echo "Python 3 не найден. Установка Python 3..."
        apt update && apt install -y python3
    else
        echo "Python 3 уже установлен. Проверка обновлений..."
        apt-get upgrade -y python3
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
    log "Создание виртуального окружения..."
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        log "Виртуальное окружение создано"
    else
        log "Виртуальное окружение уже существует"
    fi
    
    log "Активация виртуального окружения"
    source venv/bin/activate
}


echo "Установка или обновление необходимых пакетов"
install_or_update_python                             # Установка или обновление python
install_or_update_pip                                # Установка или обновление pip

echo "Инициализация виртуального окружения..."
init_venv

echo "Установка зависимостей из requirements.txt..."
pip3 install -r /opt/requirements.txt

echo "Запуск QUIC клиента..."
python3 /opt/quic-client.py

deactivate                                           # Деактивируем виртуальное окружение