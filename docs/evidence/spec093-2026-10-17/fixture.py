from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import json
uid='00000000-0000-4000-8000-000000000093'
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args): pass
 def do_GET(self): self.handle_request()
 def do_POST(self): self.handle_request()
 def do_PATCH(self): self.handle_request()
 def handle_request(self):
  body=json.loads(self.rfile.read(int(self.headers.get('Content-Length','0'))) or '{}')
  path=self.path; status=200
  print(self.command,path,flush=True)
  with open('/tmp/spec093-ios-fixture-requests.log','a') as log: log.write(self.command+' '+path+'\n')
  if path in ['/auth/email/register/code','/auth/email/forgot','/auth/email/reset','/me/timezone','/events']: status=204; value=None
  elif path in ['/auth/email/login','/auth/email/register']:
   if path.endswith('/register') and body.get('code')!='123456': status=401;value={'error':'AUTH_INVALID_SIGNUP_CODE'}
   else:
    role='coach' if body.get('email','').startswith('coach') else 'coached_student'
    value={'user':{'id':uid,'phone':None,'email':body.get('email'),'role':role,'createdAt':'2026-10-17T00:00:00.000Z'},'accessToken':'synthetic-'+role,'refreshToken':'synthetic-refresh'}
  elif path=='/auth/challenge': value={'nonce':'synthetic-challenge','expiresAt':'2027-10-17T00:00:00.000Z'}
  elif path=='/auth/refresh': status=401;value={'error':'AUTH_REFRESH_EXPIRED'}
  elif path=='/me': value={'id':uid,'phone':None,'email':'student@example.com','role':'coached_student','name':'Example Student','created_at':'2026-10-17T00:00:00.000Z'}
  elif path.endswith('/onboarding'): value={'user_id':uid,'created_at':'2026-10-17T00:00:00.000Z','updated_at':'2026-10-17T00:00:00.000Z'}
  elif '/plans' in path: value={'plans':[]}
  elif path=='/exercises': value={'exercises':[]}
  elif '/sets?' in path or '/set-logs' in path: value={'logs':[]}
  elif path=='/bind-requests/mine': value={'bind_request':None}
  elif path=='/coach/invite-codes': value={'invite_codes':[{'id':'00000000-0000-4000-8000-000000000094','coach_id':uid,'code':'XK7MPQ2RVT','type':'personal_permanent','max_uses':None,'used_count':0,'expires_at':None,'revoked_at':None,'label':None,'created_at':'2026-10-17T00:00:00.000Z'}]}
  elif path=='/coach/students': value={'students':[]}
  else: status=404;value={'error':'NOT_FOUND'}
  payload=b'' if value is None else json.dumps(value).encode()
  self.send_response(status);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(payload)
ThreadingHTTPServer(('127.0.0.1',3095),Handler).serve_forever()
