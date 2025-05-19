import asyncio
import random
from datetime import datetime
from aioquic.quic.configuration import QuicConfiguration
from aioquic.asyncio.client import connect
from aioquic.h3.connection import H3_ALPN, H3Connection
from aioquic.h3.events import HeadersReceived, DataReceived
from aioquic.asyncio.protocol import QuicConnectionProtocol

def generate_fuzz_payload(length=100):
    chars = list(range(0x20, 0x7F)) + [0x00, 0x0A, 0x0D]
    return bytes(random.choice(chars) for _ in range(length))

class ExploitClientProtocol(QuicConnectionProtocol):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._http = None
        self._response_waiter = asyncio.Future()
    
    async def send_request(self, headers, data):
        if self._http is None:
            self._http = H3Connection(self._quic)
        
        # Создаем новый stream
        stream_id = self._quic.get_next_available_stream_id()
        self._http.send_headers(
            stream_id=stream_id,
            headers=headers,
 #           end_headers=True,
            end_stream=False
        )
        self._http.send_data(
            stream_id=stream_id,
            data=data,
            end_stream=True
        )
        
        return await self._response_waiter

    def quic_event_received(self, event):
        if self._http is None:
            self._http = H3Connection(self._quic)
        
        for http_event in self._http.handle_event(event):
            if isinstance(http_event, DataReceived):
                if not self._response_waiter.done():
                    self._response_waiter.set_result(http_event.data)

class QuicExploitClient:
    def __init__(self, host: str, port: int):
        self.host = host
        self.port = port
        self.configuration = QuicConfiguration(
            is_client=True,
            alpn_protocols=H3_ALPN,
            verify_mode=0
        )

    async def send_exploit_payload(self, iteration: int):
        try:
            async with connect(
                host=self.host,
                port=self.port,
                configuration=self.configuration,
                create_protocol=ExploitClientProtocol,
            ) as protocol:
                headers = [
                    (b":method", b"GET"),
                    (b":path", b"/?" + generate_fuzz_payload(50)),
                    (b":scheme", b"https"),
                    (b":authority", self.host.encode()),
                    (b"user-agent", b"haCker Exploit Client"),
                    (b"x-malicious", generate_fuzz_payload(100))
                ]
                
                response = await protocol.send_request(
                    headers=headers,
                    data=b"EXPLOIT_PAYLOAD"
                )
                
                self.analyze_response(response, iteration)

        except Exception as e:
            print(f"[{iteration}] ❌ Error: {str(e)}")

    def analyze_response(self, response: bytes, iteration: int):
        if response:
            print(f"[{iteration}] ✅ Response ({len(response)} bytes)")
            with open("/opt/haCker_client_log.txt", "ab") as f:
                f.write(f"[{datetime.now()}] Response: {response[:200]}\n".encode())
        else:
            print(f"[{iteration}] ❌ Empty response")

    async def run_exploit(self, threads=10):
        tasks = []
        for i in range(threads):
            print(f"Запуск {threads} потоков отправки вредоносных данных...")
            task = asyncio.create_task(self.send_exploit_payload(i))
            tasks.append(task)
            await asyncio.sleep(0.2)  # Небольшая задержка между запросами
        
        await asyncio.gather(*tasks)

if __name__ == "__main__":
    print("Implementation QUIC Exploit Client - Отправка вредоносной нагрузки")
    print("Цель: vulnerable server QUIC aka 'vsQUIC'")
    
    client = QuicExploitClient("172.16.239.20", 9898)
    asyncio.run(client.run_exploit(threads=10))
