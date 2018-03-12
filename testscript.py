#!/usr/bin/env python
import sys
import telnetlib
import json

#for x in range(0, 10):
telnet = telnetlib.Telnet(sys.argv[1], 1705)


jsonstring = json.dumps({'jsonrpc':'2.0', 'method':'Client.SetVolume', 'params':{'id':sys.argv[2], 'volume':{'muted':bool(sys.argv[3]), 'percent':int(sys.argv[4])}}, 'id':1})+"\r\n"
#jsonstring = json.dumps({'params':{'id':sys.argv[2], 'volume':{'muted':sys.argv[3], 'percent':sys.argv[4]}}, 'method':'Client.SetVolume', 'jsonrpc':'2.0', 'id':1})+"\r\n"
telnet.write(jsonstring)
response = telnet.read_until("\r\n", 2)
print("sent to json:" + jsonstring)
print("recv: " + response)
telnet.close
