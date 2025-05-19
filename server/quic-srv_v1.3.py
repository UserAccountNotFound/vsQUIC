import asyncio
from aioquic.asyncio import QuicConnectionProtocol, serve
from aioquic.quic.configuration import QuicConfiguration
from aioquic.h3.connection import H3_ALPN, H3Connection
from aioquic.h3.events import HeadersReceived, DataReceived

class VulnerableQuicServerProtocol(QuicConnectionProtocol):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._http = None

    def quic_event_received(self, event):
        if self._http is None:
            self._http = H3Connection(self._quic)
        
        if isinstance(event, HeadersReceived):
            self.handle_request(event)

    def handle_request(self, event):
        headers = event.headers
        print(f"Received request with {len(headers)} headers")
        
        response_headers = [
            (b":status", b"200"),
            (b"content-type", b"text/plain"),
        ]
        
        response_data = b"Received headers:\n"
        for name, value in headers:
            response_data += name + b": " + value + b"\n"
        
        stream_id = event.stream_id
        self._http.send_headers(stream_id=stream_id, headers=response_headers)
        self._http.send_data(stream_id=stream_id, data=response_data, end_stream=True)

async def run_server():
    configuration = QuicConfiguration(
        is_client=False,
        alpn_protocols=H3_ALPN,
    )
    
    print("проверка наличия сертификатов...")
    configuration.load_cert_chain("/opt/ENV/cert-srv.pem", "/opt/ENV/key-srv.pem")
    print("Сертификаты загружены")

    try:
        server = await serve(
            host="0.0.0.0",
            port=4433,
            configuration=configuration,
            create_protocol=VulnerableQuicServerProtocol,
            retry=True,
        )
        print("QUIC/HTTP3 сервер запущен на 0.0.0.0:4433")
        await asyncio.Future()  # всегда запущен 
    except Exception as e:
        print(f"Ошибка запуска сервера: {e}")

if __name__ == "__main__":
    print("Запуск QUIC/HTTP3 сервера...")
    asyncio.run(run_server())