# Памятка для ЛЕНтяев

Самоподписанный сертификат и ключ:
'''
openssl req -x509 -newkey rsa:4096 -keyout key-srv.pem -out cert-srv.pem -days 365 -nodes -subj "/CN=VulnerableQuicServer"
'''

Установка зависимостей:
'''
pip install aioquic pyopenssl
'''