#!/usr/bin/env python3
"""Local API acceptance; start virtual_tomato.py on 8766 first."""
import json
from urllib.request import Request,urlopen
from urllib.error import HTTPError
base='http://127.0.0.1:8766/'
token=json.load(urlopen(base+'session'))['token']
def call(path,text,auth=True):
 req=Request(base+path,data=json.dumps({'text':text}).encode(),headers={'X-Tomato-Token':token if auth else 'invalid','Content-Type':'application/json'})
 return json.load(urlopen(req,timeout=60))
p=call('interpret','What is (57 + 19) AND 0x3F?')
r=call('execute',p['original'])
assert r['job']==p['job'] and r['canonical']==p['canonical']
assert r['target']=='Tomato RTL simulation'
assert any('0x0000000C' in x['text'] and x['type']==33 for x in r['replies'])
for path,text,auth,status in [('interpret','/calc 1 / 0',True,400),('execute','1+2',False,403)]:
 try:call(path,text,auth)
 except HTTPError as e:assert e.code==status
 else:raise AssertionError('invalid request accepted')
for headers in ({'Host':'example.com'},{'Origin':'https://example.com'}):
 try:urlopen(Request(base+'session',headers=headers))
 except HTTPError as e:assert e.code==403
 else:raise AssertionError('untrusted local-service request accepted')
print('PASS: canonical bytecode parity, RTL result, authorization, Host and Origin checks')
