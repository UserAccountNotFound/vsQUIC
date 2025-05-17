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


# Установка или обновление Python 3
install_or_update_python

# Установка или обновление pip
install_or_update_pip

# Создаем виртуальное окружение
echo "Создание виртуального окружения..."
python3 -m venv venv
source venv/bin/activate

# Устанавливаем зависимости из requirements.txt
echo "Установка зависимостей из requirements.txt..."
pip3 install -r /opt/requirements.txt

# Запускаем сервер
echo "Запуск QUIC сервера..."
python3 /opt/quic-srv.py

# Деактивируем виртуальное окружение
deactivate
