# Памятка для ЛЕНтяев


``` bash
apt update && apt install locales -y && \
timedatectl set-timezone Europe/Moscow && \
dpkg-reconfigure locales
```
** для удобства дальнейшей работы выбираем локаль ru_RU.UTF-8


Добавление репозитория Docker и его установка
``` bash
apt update && \
apt install ca-certificates curl gnupg sudo -y && \
install -m 0755 -d /etc/apt/keyrings && \
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg  && \
chmod a+r /etc/apt/keyrings/docker.gpg && \
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update && \
apt install -y mc docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin mc git net-tools openssl -y && \
apt update && apt upgrade -y

```

``` bash
cd /opt && \
git clone https://github.com/UserAccountNotFound/vsQUIC.git && \
cd ./vsQUIC
```

Самоподписанный сертификат и ключ:

``` bash
openssl req -x509 -newkey rsa:4096 -keyout /opt/vsQUIC/server/cert/key-srv.pem -out /opt/vsQUIC/server/cert/cert-srv.pem -days 365 -nodes >
```

Управление контейнерами докера

старт

``` bash
docker compose up -d
```

стоп

``` bash
docker compose down
```

посмотреть вывод консолей контейнеров

```bash
docker compose logs -f
```
