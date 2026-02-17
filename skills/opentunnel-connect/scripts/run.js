const { spawn } = require('child_process');
const http = require('http');

const PORT = 3000;
const SSH_KEY = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzn4bIIjxL+VO6WCjrvF+rxt3LVi4s4X57ZwP4wnG1h julianponguta@gmail.com';
const SSH_KEY_PATH = 'C:/Users/Julian/.ssh/id_ed25519';
let credentials = null;

console.log('Starting OpenTunnel...');

const tunnel = spawn('powershell', [
  '-NoProfile', '-Command',
  'ssh -o StrictHostKeyChecking=no -R 80:localhost:3000 nokey@localhost.run'
], { stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true });

let url = '';

tunnel.stdout.on('data', (data) => {
  const text = data.toString();
  const match = text.match(/([a-zA-Z0-9.-]+)\.lhr\.life/);
  if (match && !url) url = match[1] + '.lhr.life';
});

tunnel.stderr.on('data', (data) => {
  const text = data.toString();
  const match = text.match(/([a-zA-Z0-9.-]+)\.lhr\.life/);
  if (match && !url) url = match[1] + '.lhr.life';
});

function startServer() {
  if (!url) { setTimeout(startServer, 1000); return; }

  console.log('');
  console.log('========================================');
  console.log('RUN THIS COMMAND ON REMOTE SERVER:');
  console.log('');
  console.log(`curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- ${url} 60 tunneluser "${SSH_KEY}"`);
  console.log('');
  console.log('========================================');
  console.log('');

  const server = http.createServer((req, res) => {
    if (req.method === 'POST' && req.url === '/connect') {
      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', () => {
        try {
          credentials = JSON.parse(body);
          console.log('');
          console.log('========================================');
          console.log('CREDENTIALS RECEIVED!');
          console.log(JSON.stringify(credentials, null, 2));
          console.log('========================================');
          console.log('');
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ status: 'ok' }));
          
          setTimeout(() => {
            console.log('Connecting via SSH...');
            
            const ssh = spawn('ssh', [
              '-o', 'StrictHostKeyChecking=no',
              '-o', 'IdentitiesOnly=yes',
              '-i', SSH_KEY_PATH,
              '-p', String(credentials.port),
              `${credentials.user}@${credentials.host}`,
              'echo "========================================" && echo "CONNECTED TO SERVER!" && hostname && whoami && echo "========================================"'
            ], { stdio: 'inherit' });
            
            ssh.on('close', (code) => {
              console.log('SSH session ended');
              process.exit(0);
            });
          }, 1000);
        } catch (e) {
          res.writeHead(500);
          res.end();
        }
      });
    } else {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end('<h1>Waiting...</h1>');
    }
  });

  server.listen(PORT, '127.0.0.1', () => {
    let countdown = 60;
    const interval = setInterval(() => {
      if (credentials) { clearInterval(interval); return; }
      countdown--;
      if (countdown < 0) {
        clearInterval(interval);
        console.log('TIMEOUT - No credentials received');
        process.exit(0);
      }
    }, 1000);
  });
}

setTimeout(startServer, 15000);
