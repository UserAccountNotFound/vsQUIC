#!/usr/bin/env bash

# Проверяем, установлен ли Python 3
if ! command -v python3 &> /dev/null; then
    echo "Python 3 не найден. Установите его и повторите попытку."
    exit 1
fi

# Проверяем, установлен ли pip
if ! command -v pip3 &> /dev/null; then
    echo "pip3 не найден. Установите pip и повторите попытку."
    exit 1
fi

# Создаем виртуальное окружение
echo "Создание виртуального окружения..."
python3 -m venv venv
source venv/bin/activate

# Устанавливаем зависимости из requirements.txt
echo "Установка зависимостей из requirements.txt..."
pip3 install -r requirements.txt

# Запускаем сервер
echo "Запуск QUIC сервера..."
python3 /opt/quic-client.py

# Деактивируем виртуальное окружение
deactivate