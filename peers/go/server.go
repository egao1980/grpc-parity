// Tiny grpc-go echo: unary Ping + server-stream Watch + bidi Chat.
// Mirrors peers/python/server.py. TLS if cert/key given.
package main

import (
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"os"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/status"
)

type echoMsg struct {
	raw []byte
}

type echoCodec struct{}

func (echoCodec) Name() string { return "proto" }

func (echoCodec) Marshal(v any) ([]byte, error) {
	m, ok := v.(*echoMsg)
	if !ok {
		return nil, fmt.Errorf("echoCodec.Marshal: %T", v)
	}
	return append([]byte(nil), m.raw...), nil
}

func (echoCodec) Unmarshal(data []byte, v any) error {
	m, ok := v.(*echoMsg)
	if !ok {
		return fmt.Errorf("echoCodec.Unmarshal: %T", v)
	}
	m.raw = append([]byte(nil), data...)
	return nil
}

func decodeBody(raw []byte) []byte {
	if len(raw) == 0 || raw[0] != 0x0a {
		return append([]byte(nil), raw...)
	}
	n, shift, pos := 0, 0, 1
	for {
		if pos >= len(raw) {
			return nil
		}
		b := raw[pos]
		pos++
		n |= int(b&0x7f) << shift
		if b&0x80 == 0 {
			if pos+n > len(raw) {
				return raw[pos:]
			}
			return raw[pos : pos+n]
		}
		shift += 7
	}
}

func encodeBody(body []byte) []byte {
	n := len(body)
	out := make([]byte, 0, 1+binary.MaxVarintLen64+n)
	out = append(out, 0x0a)
	for n >= 0x80 {
		out = append(out, byte(n)|0x80)
		n >>= 7
	}
	out = append(out, byte(n))
	return append(out, body...)
}

func echoHandler(_ any, stream grpc.ServerStream) error {
	full, ok := grpc.MethodFromServerStream(stream)
	if !ok {
		return status.Error(codes.Internal, "missing method")
	}
	switch full {
	case "/echo.Echo/Ping":
		in := new(echoMsg)
		if err := stream.RecvMsg(in); err != nil {
			return err
		}
		return stream.SendMsg(in)
	case "/echo.Echo/Watch":
		in := new(echoMsg)
		if err := stream.RecvMsg(in); err != nil {
			return err
		}
		body := decodeBody(in.raw)
		for i := 0; i < 3; i++ {
			out := append(append([]byte{}, body...), byte(i))
			if err := stream.SendMsg(&echoMsg{raw: encodeBody(out)}); err != nil {
				return err
			}
		}
		return nil
	case "/echo.Echo/Chat":
		for {
			in := new(echoMsg)
			if err := stream.RecvMsg(in); err != nil {
				if err == io.EOF {
					return nil
				}
				return err
			}
			if err := stream.SendMsg(in); err != nil {
				return err
			}
		}
	default:
		return status.Errorf(codes.Unimplemented, "unknown %s", full)
	}
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: server PORT [CERT KEY]")
		os.Exit(2)
	}
	port := os.Args[1]
	cert := ""
	key := ""
	if len(os.Args) > 3 {
		cert = os.Args[2]
		key = os.Args[3]
	}
	lis, err := net.Listen("tcp", "127.0.0.1:"+port)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	opts := []grpc.ServerOption{
		grpc.ForceServerCodec(echoCodec{}),
		grpc.UnknownServiceHandler(echoHandler),
	}
	if cert != "" && key != "" {
		creds, err := credentials.NewServerTLSFromFile(cert, key)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		opts = append(opts, grpc.Creds(creds))
	}
	s := grpc.NewServer(opts...)
	fmt.Printf("LISTEN %s\n", port)
	if err := s.Serve(lis); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
