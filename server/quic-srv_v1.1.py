import asyncio
from aioquic.asyncio import serve
from aioquic.quic.configuration import QuicConfiguration
from aioquic.h3.connection import H3_ALPN, H3Connection
from aioquic.h3.events import HeadersReceived, DataReceived

class VulnerableQuicServerProtocol(asyncio.Protocol):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._http = None

    def connection_made(self, transport):
        self._transport = transport
        self._http = H3Connection(transport)

    def datagram_received(self, data, addr):
        if self._http is None:
            print("New QUIC connection from", addr)
            self._http = H3Connection(self._transport)
        
        try:
            events = self._http.handle_event(data)
            for event in events:
                if isinstance(event, HeadersReceived):
                    self.handle_request(event)
        except Exception as e:
            print(f"Ошибка обработки запроса: {e}")

    def handle_request(self, event):
        headers = event.headers
        print(f"Received request with {len(headers)} headers")
        
        # Уязвимый обработчик - просто возвращаем все полученные заголовки, без каких либо проверок
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
    
    # Укажите пути к вашим сертификатам
    configuration.load_cert_chain("/opt/ENV/cert-srv.pem", "/opt/ENV/key-srv.pem")
    
    server = await serve(
        host="0.0.0.0",
        port=4433,
        configuration=configuration,
        create_protocol=VulnerableQuicServerProtocol,
    )
    
    print("QUIC/HTTP3 сервер запущен на 0.0.0.0:4433")
    await server.serve_forever()

if __name__ == "__main__":
    print("Запуск QUIC/HTTP3 сервера...")
    asyncio.run(run_server())