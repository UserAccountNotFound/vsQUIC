# vsQUIC

## Разбор уязвимости:

1. Фиксированный буфер: В коде используется фиксированный буфер meta_buffer размером 256 байт без проверки длины входных данных.

2. Отсутствие санитизации: Метатеги добавляются в ответ без какой-либо проверки или кодирования.

3. QUIC-специфика: В QUIC уязвимости переполнения буфера могут быть особенно опасны из-за мультиплексирования потоков.

## Пример вредоносной нагрузки:

Злоумышленник отправляет запрос с очень длинным метатегом:

'''
GET / HTTP/3
meta:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA (вобщем больше 256 символов)
'''

Это может привести к:
1. Переполнению буфера
2. Возможности выполнения произвольного кода
3. Краху сервера
