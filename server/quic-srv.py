import sys
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.connection import QuicConnection
from aioquic.h3.connection import H3_ALPN, H3Connection
from aioquic.h3.events import HeadersReceived, DataReceived
from aioquic.tls import SessionTicket

class VulnerableQuicServer:
    def __init__(self):
        self.configuration = QuicConfiguration(
            is_client=False,
            alpn_protocols=H3_ALPN,
        )
        self.configuration.load_cert_chain("/opt/cert/cert-srv.pem", "/opt/cert/key-srv.pem")
        
    async def handle_request(self, stream_id: int, headers: list, data: bytes):
        # Уязвимая обработка заголовков - отсутствие проверки длины
        meta_tags = []
        for name, value in headers:
            if name == b"meta":
                # Уязвимость: копирование без проверки длины в фиксированный буфер
                meta_buffer = bytearray(256)  # Фиксированный буфер
                meta_buffer[:len(value)] = value  # Возможное переполнение
                meta_tags.append(meta_buffer.decode('utf-8', errors='ignore'))
        
        # Формируем ответ с уязвимыми метатегами
        response = b"HTTP/3 200 OK\r\n"
        response += b"Content-Type: text/html\r\n\r\n"
        response += b"<html><head>"
        
        # Добавляем метатеги без санитизации
        # т.е без проверок - когда сохраняются только те теги и атрибуты, которые обозначены как «безопасные»
        for tag in meta_tags:
            response += f"<meta name=\"vuln\" content=\"{tag}\">".encode()
            
        response += b"</head><body>Vulnerable QUIC Server</body></html>"
        
        return response

    async def run(self, host: str, port: int):
        # Упрощенная реализация сервера для демонстрации уязвимости
        print(f"Starting vulnerable QUIC server on {host}:{port}")
        
        while True:
            try:
                # Здесь должен быть код принятия соединения и обработки запросов
                # В реальном коде уязвимость может проявляться при обработке большого количества метатегов
                # или очень длинных значений метатегов
                pass
            except Exception as e:
                print(f"Error: {e}")

if __name__ == "__main__":
    server = VulnerableQuicServer()
    
    # Пример полезной нагрузки для эксплуатации уязвимости
    print("Пример вредоносного запроса:")
    print("1. Отправка очень длинного метатега (>256 байт)")
    print("2. Использование специальных символов для обхода проверок")
    print("3. Возможность выполнения произвольного кода через переполнение буфера")
    
    # Запуск сервера (в реальном PoC здесь был бы код для эксплуатации)
    import asyncio
    asyncio.run(server.run("0.0.0.0", 4433))
