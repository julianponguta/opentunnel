const express = require('express');
const { spawn, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const app = express();
app.use(express.json());

let credentials = null;
let boreProcess = null;
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
    } catch (e) {
        console.error('Failed to create flag:', e.message);
    }
}

function installBore() {
    if (commandExists('bore')) {
        return true;
    }
    
    console.log('Installing bore...');
    
    try {
        const version = '0.6.0';
        const arch = process.arch === 'x64' ? 'x86_64' : 'aarch64';
        
        if (process.platform === 'win32') {
            const url = `https://github.com/ekzhang/bore/releases/download/v${version}/bore-v${version}-${arch}-pc-windows-msvc.zip`;
            const AdmZip = require('adm-zip');
            const tempZip = path.join(os.tmpdir(), 'bore.zip');
            
            execSync(`curl -fsSL "${url}" -o "${tempZip}"`, { stdio: 'ignore' });
            
            const binDir = path.join(SESSION_DIR, 'bin');
            ensureDir();
            
            const zip = new AdmZip(tempZip);
            zip.extractAllTo(binDir, true);
            
            fs.unlinkSync(tempZip);
        } else {
            const url = `https://github.com/ekzhang/bore/releases/download/v${version}/bore-v${version}-${arch}-unknown-linux-musl.tar.gz`;
            const binDir = path.join(SESSION_DIR, 'bin');
            ensureDir();
            
            execSync(`curl -fsSL "${url}" | tar -xz -C "${binDir}"`, { stdio: 'ignore' });
            fs.chmodSync(path.join(binDir, 'bore'), '755');
        }
        
        return true;
    } catch (e) {
        console.error('Failed to install bore:', e.message);
        return false;
    }
}

function commandExists(cmd) {
    try {
        execSync(`${cmd} --version`, { stdio: 'ignore' });
        return true;
    } catch (e) {
        return false;
    }
}

function getBorePath() {
    const binDir = path.join(SESSION_DIR, 'bin');
    const borePath = path.join(binDir, process.platform === 'win32' ? 'bore.exe' : 'bore');
    
    if (fs.existsSync(borePath)) {
        return borePath;
    }
    
    return 'bore';
}

function startBoreTunnel(port) {
    return new Promise((resolve, reject) => {
        const borePath = getBorePath();
        
        console.log('Starting bore tunnel...');
        
        boreProcess = spawn(borePath, ['local', String(port), '--to', 'bore.pub'], {
            stdio: ['ignore', 'pipe', 'pipe']
        });
        
        let boreUrl = '';
        
        boreProcess.stdout.on('data', (data) => {
            const output = data.toString();
            console.log('[bore]', output.trim());
            
            const match = output.match(/bore\.pub:(\d+)/);
            if (match) {
                boreUrl = match[1];
            }
        });
        
        boreProcess.stderr.on('data', (data) => {
            const output = data.toString();
            console.log('[bore]', output.trim());
            
            const match = output.match(/bore\.pub:(\d+)/);
            if (match) {
                boreUrl = match[1];
            }
        });
        
        boreProcess.on('error', (err) => {
            console.error('[bore error]', err.message);
        });
        
        let attempts = 0;
        const maxAttempts = 30;
        
        const check = setInterval(() => {
            attempts++;
            
            if (boreUrl) {
                clearInterval(check);
                resolve(boreUrl);
            } else if (attempts >= maxAttempts) {
                clearInterval(check);
                reject(new Error('Timeout waiting for bore'));
            } else {
                process.stdout.write('.');
            }
        }, 1000);
    });
}

function stopBore() {
    if (boreProcess) {
        try {
            boreProcess.kill('SIGTERM');
        } catch (e) {}
        boreProcess = null;
    }
}

function stopServer() {
    stopBore();
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
    
    res.json({ status: 'ok', message: 'Credentials received' });
    
    setTimeout(() => {
        console.log('Shutting down webhook server...');
        stopServer();
        process.exit(0);
    }, 2000);
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

async function start(port = 3000) {
    if (!checkDependencies()) {
        console.log('First run...');
        markInstalled();
    }
    
    if (!installBore()) {
        throw new Error('Failed to install bore');
    }
    
    console.log(`Starting webhook server on port ${port}...`);
    
    const borePort = await startBoreTunnel(port);
    
    return new Promise((resolve) => {
        server = app.listen(port, '127.0.0.1', () => {
            console.log(`Webhook server ready!`);
        });
        
        resolve({ port: borePort, credentials: null });
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
    start(port).then(({ port: borePort }) => {
        console.log('');
        console.log('========================================');
        console.log('Server running! Share this URL:');
        console.log(`bore.pub:${borePort}`);
        console.log('========================================');
        console.log('');
    }).catch(err => {
        console.error('Failed to start:', err.message);
        process.exit(1);
    });
}

module.exports = { start, getCredentials, shutdown, app };
