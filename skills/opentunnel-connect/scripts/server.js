const express = require('express');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const app = express();
app.use(express.json());

let credentials = null;
let tunnelProcess = null;
let server = null;

const SESSION_DIR = path.join(os.homedir(), '.opentunnel');
const FLAG_FILE = path.join(SESSION_DIR, 'installed');

function ensureDir() {
    if (!fs.existsSync(SESSION_DIR)) {
        fs.mkdirSync(SESSION_DIR, { recursive: true });
    }
}

function checkDependencies() {
    ensureDir();
    return fs.existsSync(FLAG_FILE);
}

function markInstalled() {
    try {
        ensureDir();
        fs.writeFileSync(FLAG_FILE, new Date().toISOString());
    } catch (e) {}
}

function startLocalhostRunTunnel(port) {
    return new Promise((resolve, reject) => {
        console.log('Starting localhost.run tunnel...');
        
        const isWindows = process.platform === 'win32';
        
        let cmd, args;
        
        if (isWindows) {
            cmd = 'powershell';
            args = ['-NoProfile', '-Command', `ssh -o StrictHostKeyChecking=no -R 80:localhost:${port} nokey@localhost.run`];
        } else {
            cmd = 'ssh';
            args = ['-o', 'StrictHostKeyChecking=no', '-R', `80:localhost:${port}`, 'nokey@localhost.run'];
        }
        
        tunnelProcess = spawn(cmd, args, {
            stdio: ['ignore', 'pipe', 'pipe'],
            shell: false,
            windowsHide: true
        });
        
        let url = '';
        
        tunnelProcess.stdout.on('data', (data) => {
            const text = data.toString();
            console.log('[localhost.run]', text.trim());
            
            const match = text.match(/([a-zA-Z0-9.-]+)\.lhr\.life/);
            if (match) {
                url = match[1];
            }
        });
        
        tunnelProcess.stderr.on('data', (data) => {
            const text = data.toString();
            console.log('[localhost.run]', text.trim());
            
            const match = text.match(/([a-zA-Z0-9.-]+)\.lhr\.life/);
            if (match) {
                url = match[1];
            }
        });
        
        tunnelProcess.on('error', (err) => {
            console.error('[error]', err.message);
        });
        
        let attempts = 0;
        const maxAttempts = 30;
        
        const check = setInterval(() => {
            attempts++;
            
            if (url) {
                clearInterval(check);
                resolve(url + '.lhr.life');
            } else if (attempts >= maxAttempts) {
                clearInterval(check);
                reject(new Error('Timeout waiting for tunnel'));
            } else {
                process.stdout.write('.');
            }
        }, 1000);
    });
}

function stopTunnel() {
    if (tunnelProcess) {
        try {
            tunnelProcess.kill('SIGTERM');
        } catch (e) {}
        tunnelProcess = null;
    }
}

function stopServer() {
    stopTunnel();
    if (server) {
        try {
            server.close();
        } catch (e) {}
        server = null;
    }
}

app.post('/connect', (req, res) => {
    const { user, password, host, port } = req.body;
    
    console.log('Received credentials:', { user, host, port });
    
    credentials = { user, password, host, port };
    
    res.json({ status: 'ok', message: 'Credentials received', credentials });
});

app.get('/status', (req, res) => {
    if (credentials) {
        res.json({ status: 'ready', credentials });
    } else {
        res.json({ status: 'waiting' });
    }
});

app.get('/health', (req, res) => {
    res.json({ status: 'ok' });
});

app.get('/', (req, res) => {
    if (credentials) {
        res.send(`
            <h1>OpenTunnel Connected!</h1>
            <pre>${JSON.stringify(credentials, null, 2)}</pre>
        `);
    } else {
        res.send('<h1>Waiting for credentials...</h1>');
    }
});

async function start(port = 3000) {
    if (!checkDependencies()) {
        markInstalled();
    }
    
    console.log(`Starting webhook server on port ${port}...`);
    
    const tunnelUrl = await startLocalhostRunTunnel(port);
    
    return new Promise((resolve) => {
        server = app.listen(port, '127.0.0.1', () => {
            console.log(`Webhook server ready!`);
        });
        
        resolve({ url: tunnelUrl, credentials: null });
    });
}

function getCredentials() {
    return credentials;
}

function shutdown() {
    stopServer();
    process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

if (require.main === module) {
    const port = parseInt(process.argv[2]) || 3000;
    start(port).then(({ url }) => {
        console.log('');
        console.log('========================================');
        console.log('Server running! Share this URL:');
        console.log(url);
        console.log('========================================');
        console.log('');
    }).catch(err => {
        console.error('Failed to start:', err.message);
        process.exit(1);
    });
}

module.exports = { start, getCredentials, shutdown, app };
