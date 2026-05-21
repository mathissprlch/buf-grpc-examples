"""In-process gRPC round trip against the buf-generated Python stubs."""

import concurrent.futures
import os
import sys

# Make the generated package importable.
GEN_ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "gen", "python")
sys.path.insert(0, os.path.abspath(GEN_ROOT))

import grpc  # noqa: E402

from greet.v1 import greet_pb2, greet_pb2_grpc  # noqa: E402


class GreetServicer(greet_pb2_grpc.GreetServiceServicer):
    def Greet(self, request, context):
        return greet_pb2.GreetResponse(greeting=f"Hello, {request.name}")


def main() -> None:
    server = grpc.server(concurrent.futures.ThreadPoolExecutor(max_workers=1))
    greet_pb2_grpc.add_GreetServiceServicer_to_server(GreetServicer(), server)
    port = server.add_insecure_port("127.0.0.1:0")
    server.start()
    try:
        with grpc.insecure_channel(f"127.0.0.1:{port}") as channel:
            stub = greet_pb2_grpc.GreetServiceStub(channel)
            response = stub.Greet(greet_pb2.GreetRequest(name="Python"))
    finally:
        server.stop(grace=None)

    assert response.greeting == "Hello, Python", response.greeting
    print("python gRPC round trip ok:", response.greeting)


if __name__ == "__main__":
    main()
