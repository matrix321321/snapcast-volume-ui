#!/usr/bin/env python
import sys
import telnetlib
import json
import threading
import time

telnet = telnetlib.Telnet('127.0.0.1', 1705)
requestId = 1

def doRequest( j, requestId ):
	print("send: " + j)
	telnet.write(j + "\r\n")
	while (True):
		response = telnet.read_until("\r\n", 2)
		jResponse = json.loads(response)
		if 'id' in jResponse:
			if jResponse['id'] == requestId:
				return jResponse;
	return;

def setVolume(client, percent, muted):
	global requestId
	doRequest(json.dumps({'jsonrpc': '2.0', 'method': 'Client.SetVolume', 'params': {'client':  client,  'volume': {'muted': muted, 'percent': percent }}, 'id': requestId}), requestId)
	#doRequest(json.dumps({'id': requestId, 'jsonrpc': '2.0', 'method': 'Client.SetVolume', 'params': {'client':  client,  'volume': {'muted': muted, 'percent': volume }}), requestId)
	requestId = requestId + 1

percent = int(sys.argv[2])
muted = sys.argv[3]
setVolume(sys.argv[1], percent, muted)

telnet.close
