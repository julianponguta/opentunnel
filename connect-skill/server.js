const express = require('express');
const { spawn, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());

let credentials = null;
let boreProcess = null;
let server = null;

const FLAG_FILE = path.join(process.env.HOME || process.env.USERPROFILE, '.opentunnel-installed');

function checkDependencies() {
    if (fs.existsSync(FLAG_FILE)) {
        console.log('Dependencies already installed (flag found)');
        return true;
    }
    return false;
}

function markInstalled() {
    try {
        fs.writeFileSync(FLAG_FILE, new Date().toISOString());
        console.log('Flag created: ' + FLAG_FILE);
    } catch (e) {
        console.error('Failed to create flag:', e.message);
    }
}

function installDependencies() {
    if (checkDependencies()) {
        return true;
    }
    
    console.log('Checking dependencies...');
    
    // Check Node.js
    try {
        execSync('node --version', { stdio: 'ignore' });
    } catch (e) {
        console.error('Node.js not found. Please install Node.js first.');
        return false;
    }
    
    // Install npm packages
    try {
        console.log('Installing express...');
        execSync('npm install express', { stdio: 'inherit' });
    } catch (e) {
        console.error('Failed to install express:', e.message);
        return false;
    }
    
    // Install bore
    if (!installBore()) {
        return false;
    }
    
    markInstalled();
    return true;
}

function installBore() {
    try {
        execSync('bore --version', { stdio: 'ignore' });
        return true;
    } catch (e) {
        console.log('Installing bore...');
        const os = process.platform;
        const arch = process.arch;
        
        let boreArch = 'x86_64';
        if (arch === 'arm64') boreArch = 'aarch64';
        
        const version = '0.6.0';
        const url = `https://github.com/ekzhang/bore/releases/download/v${version}/bore-v${version}-${boreArch}-unknown-linux-musl.tar.gz`;
        
        try {
            execSync(`curl -fsSL ${url} | tar -xz -C /tmp`, { stdio: 'inherit' });
            execSync('mv /tmp/bore /usr/local/bin/bore && chmod +x /usr/local/bin/bore', { stdio: 'inherit' });
            return true;
        } catch (err) {
            console.error('Failed to install bore:', err.message);
            return false;
        }
    }
}

function startBoreTunnel(port) {
    return new Promise((resolve, reject) => {
        boreProcess = spawn('bore', ['local', String(port), '--to', 'bore.pub'], {
            stdio: ['ignore', 'pipe', 'pipe']
        });
        
        let boreUrl = '';
        
        boreProcess.stdout.on('data', (data) => {
            const output = data.toString();
            console.log('bore:', output);
            
            const match = output.match(/bore\.pub:(\d+)/);
            if (match) {
                boreUrl = match[1];
            }
        });
        
        boreProcess.stderr.on('data', (data) => {
            console.log('bore:', data.toString());
        });
        
        boreProcess.on('error', (err) => {
            reject(err);
        });
        
        setTimeout(() => {
            if (boreUrl) {
                resolve(boreUrl);
            } else {
                reject(new Error('Timeout waiting for bore'));
            }
        }, 10000);
    });
}

function stopBore() {
    if (boreProcess) {
        boreProcess.kill();
        boreProcess = null;
    }
}

function stopServer() {
    stopBore();
    if (server) {
        server.close();
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
    }, 2000);
});

app.get('/status', (req, res) => {
    if (credentials) {
        res.json({ status: 'ready', credentials });
    } else {
        res.json({ status: 'waiting' });
    }
});

async function start(port = 3000) {
    if (!installDependencies()) {
        throw new Error('Failed to install dependencies');
    }
    
    const borePort = await startBoreTunnel(port);
    
    server = app.listen(port, '127.0.0.1', () => {
        console.log(`Webhook server ready on bore.pub:${borePort}`);
    });
    
    return { port: borePort, credentials: null };
}

function getCredentials() {
    return credentials;
}

function shutdown() {
    stopServer();
    process.exit(0);
}

if (require.main === module) {
    start(3000).then(({ port }) => {
        console.log(`Server running on bore.pub:${port}`);
    }).catch(err => {
        console.error(err);
        process.exit(1);
    });
}

module.exports = { start, getCredentials, shutdown };
