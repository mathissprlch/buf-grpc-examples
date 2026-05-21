package examples

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"connectrpc.com/connect"
	greetv1 "github.com/mathissprlch/buf-grpc-examples/gen/go/greet/v1"
	"github.com/mathissprlch/buf-grpc-examples/gen/go/greet/v1/greetv1connect"
	"google.golang.org/grpc"
)

// connectServer implements the Connect-generated handler interface.
type connectServer struct{}

func (connectServer) Greet(
	_ context.Context,
	req *connect.Request[greetv1.GreetRequest],
) (*connect.Response[greetv1.GreetResponse], error) {
	return connect.NewResponse(&greetv1.GreetResponse{
		Greeting: "Hello, " + req.Msg.GetName(),
	}), nil
}

// grpcServer implements the gRPC-generated server interface.
type grpcServer struct {
	greetv1.UnimplementedGreetServiceServer
}

func (grpcServer) Greet(
	_ context.Context,
	req *greetv1.GreetRequest,
) (*greetv1.GreetResponse, error) {
	return &greetv1.GreetResponse{Greeting: "Hello, " + req.GetName()}, nil
}

// TestConnectRoundTrip exercises the Connect-generated client and handler over
// a real (loopback) HTTP server.
func TestConnectRoundTrip(t *testing.T) {
	mux := http.NewServeMux()
	mux.Handle(greetv1connect.NewGreetServiceHandler(connectServer{}))
	srv := httptest.NewServer(mux)
	defer srv.Close()

	client := greetv1connect.NewGreetServiceClient(srv.Client(), srv.URL)
	res, err := client.Greet(context.Background(), connect.NewRequest(&greetv1.GreetRequest{
		Name: "Connect",
	}))
	if err != nil {
		t.Fatalf("Greet: %v", err)
	}
	if got, want := res.Msg.GetGreeting(), "Hello, Connect"; got != want {
		t.Fatalf("greeting = %q, want %q", got, want)
	}
}

// TestGRPCRegistration confirms the gRPC-generated server registration and
// client constructor compile and wire together.
func TestGRPCRegistration(t *testing.T) {
	s := grpc.NewServer()
	greetv1.RegisterGreetServiceServer(s, grpcServer{})
	if info := s.GetServiceInfo(); len(info) == 0 {
		t.Fatal("expected a registered gRPC service")
	}
	// Compile-check the generated gRPC client constructor.
	_ = func(cc *grpc.ClientConn) greetv1.GreetServiceClient {
		return greetv1.NewGreetServiceClient(cc)
	}
}
