#!/usr/bin/python

import sys
import datetime
import SocketServer


def request_handler(request_socket):
    global n
    try:
        #request_msg = request_socket.recv(1024)
        request_socket.send(str(n))
        print "Sent ", str(n)
        n = n+1
        if n>int(sys.argv[1])-1:
           n=0
        request_socket.close()
        sys.stdout.flush()
    except Exception, ex:
        print 'e', ex,

def simple_tcp_server():
    tcp_server = SocketServer.TCPServer(("0.0.0.0", int(sys.argv[2])),
                                        RequestHandlerClass=None,
                                        bind_and_activate=True)

    while True:
        request_socket, address_port_tuple = tcp_server.get_request()
        print "Connection from: %s" % str(address_port_tuple)

        request_handler(request_socket)
        # shutdown request socket and close it
        tcp_server.shutdown_request(request_socket)

if __name__ == "__main__":
    n = 0
    print 'hello'
    print str(n)
    simple_tcp_server()
