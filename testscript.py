#!/usr/bin/env python
import sys
import telnetlib
import json

for x in range(0, 10):
    telnet = telnetlib.Telnet(sys.argv[1], 1705)
    telnet.write(json.dumps({'jsonrpc': '2.0', 'method': 'Client.SetVolume', 'params': {'id':  sys.argv[2], 'volume': {'muted': False, 'percent': 10}}, 'id': x}) + "\r\n")
    response = telnet.read_until("\r\n", 2)
    print("recv: " + response)
    telnet.close
