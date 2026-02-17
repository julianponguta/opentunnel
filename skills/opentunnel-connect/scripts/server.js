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
    if (fs.existsSync(FLAG_FILE)) {
        return true;
    }
    return false;
}

function markInstalled() {
    try {
        ensureDir();
        fs.writeFileSync(FLAG_FILE, new Date().toISOString());
        console.log('Flag created: ' + FLAG_FILE);
    } catch (e) {
        console.error('Failed to create flag:', e.message);
    }
}

function getBoreBinary() {
    const isWindows = process.platform === 'win32';
    const binDir = path.join(SESSION_DIR, 'bin');
    const borePath = path.join(binDir, isWindows ? 'bore.exe' : 'bore');
    
    if (fs.existsSync(borePath)) {
        return borePath;
    }
    
    return null;
}

function installBore() {
    const boreBin = getBoreBinary();
    if (boreBin) {
        return boreBin;
    }
    
    const isWindows = process.platform === 'win32';
    const binDir = path.join(SESSION_DIR, 'bin');
    
    ensureDir();
    if (!fs.existsSync(binDir)) {
        fs.mkdirSync(binDir, { recursive: true });
    }
    
    const version = '0.6.0';
    let url, destPath;
    
    if (isWindows) {
        const arch = process.arch === 'x64' ? 'x86_64' : 'aarch64';
        url = `https://github.com/ekzhang/bore/releases/download/v${version}/bore-v${version}-${arch}-pc-windows-msvc.zip`;
        destPath = path.join(binDir, 'bore.exe');
    } else {
        const arch = process.arch === 'x64' ? 'x86_64' : (process.arch === 'arm64' ? 'aarch64' : 'x86_64');
        url = `https://github.com/ekzhang/bore/releases/download/v${version}/bore-v${version}-${arch}-unknown-linux-musl.tar.gz`;
        destPath = path.join(binDir, 'bore');
    }
    
    console.log(`Downloading bore from ${url}...`);
    
    const tempFile = path.join(os.tmpdir(), isWindows ? 'bore.zip' : 'bore.tar.gz');
    
    try {
        execSync(`curl -fsSL "${url}" -o "${tempFile}"`, { stdio: 'inherit' });
        
        if (isWindows) {
            const AdmZip = require('adm-zip');
            const zip = new AdmZip(tempFile);
            zip.extractAllTo(binDir, true);
        } else {
            execSync(`tar -xzf "${tempFile}" -C "${binDir}"`, { shell: true });
            fs.chmodSync(destPath, '755');
        }
        
        try { fs.unlinkSync(tempFile); } catch(e) {}
        
        if (fs.existsSync(destPath)) {
            console.log('bore installed successfully');
            return destPath;
        }
    } catch (e) {
        console.error('Failed to download bore:', e.message);
    }
    
    return null;
}

function getBoreCommand() {
    const isWindows = process.platform === 'win32';
    
    if (isWindows) {
        console.log('Windows detected, using WSL for bore tunnel...');
        
        try {
            execSync('wsl -e which bore', { stdio: 'ignore' });
            console.log('bore found in WSL');
        } catch (e) {
            console.log('Installing bore in WSL...');
            try {
                execSync('wsl -e bash -c "curl -fsSL https://github.com/ekzhang/bore/releases/download/v0.6.0/bore-v0.6.0-x86_64-unknown-linux-musl.tar.gz | tar -xz -C /tmp && sudo mv /tmp/bore /usr/local/bin/ && sudo chmod +x /usr/local/bin/bore"', { 
                    stdio: 'inherit',
                    timeout: 60000
                });
            } catch (err) {
                console.error('Failed to install bore in WSL:', err.message);
            }
        }
        
        return {
            cmd: 'wsl',
            args: ['-e', 'bash', '-c', 'bore local 3000 --to bore.pub'],
            useShell: false
        };
    }
    
    let boreBin = getBoreBinary();
    
    if (!boreBin || !fs.existsSync(boreBin)) {
        boreBin = installBore();
    }
    
    if (boreBin && fs.existsSync(boreBin)) {
        return { 
            cmd: boreBin, 
            args: ['local', '3000', '--to', 'bore.pub'],
            useShell: false
        };
    }
    
    return { cmd: 'bore', args: ['local', '3000', '--to', 'bore.pub'], useShell: false };
}

function startBoreTunnel(port) {
    return new Promise((resolve, reject) => {
        const { cmd, args, useShell } = getBoreCommand();
        const actualArgs = args.map(a => String(a).replace('3000', String(port)));
        
        console.log(`Starting: ${cmd} ${actualArgs.join(' ')}`);
        
        try {
            boreProcess = spawn(cmd, actualArgs, {
                stdio: ['ignore', 'pipe', 'pipe'],
                shell: useShell,
                windowsHide: true
            });
        } catch (e) {
            reject(e);
            return;
        }
        
        let boreUrl = '';
        let stderrOutput = '';
        
        boreProcess.stdout.on('data', (data) => {
            const output = data.toString();
            console.log('[bore out]', output.trim());
            
            const match = output.match(/bore\.pub:(\d+)/);
            if (match) {
                boreUrl = match[1];
            }
        });
        
        boreProcess.stderr.on('data', (data) => {
            const output = data.toString();
            stderrOutput += output;
            console.log('[bore err]', output.trim());
            
            const match = output.match(/bore\.pub:(\d+)/);
            if (match) {
                boreUrl = match[1];
            }
        });
        
        boreProcess.on('error', (err) => {
            console.error('[bore error]', err.message);
            reject(err);
        });
        
        boreProcess.on('close', (code) => {
            if (code !== 0 && code !== null) {
                console.log('[bore closed]', `code: ${code}`);
            }
        });
        
        let attempts = 0;
        const maxAttempts = 30;
        
        const checkInterval = setInterval(() => {
            attempts++;
            
            if (boreUrl) {
                clearInterval(checkInterval);
                resolve(boreUrl);
            } else if (attempts >= maxAttempts) {
                clearInterval(checkInterval);
                reject(new Error(`Timeout waiting for bore (${maxAttempts}s). stderr: ${stderrOutput.slice(-500)}`));
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
        } catch (e) {
            console.error('Error killing bore:', e.message);
        }
        boreProcess = null;
    }
}

function stopServer() {
    stopBore();
    if (server) {
        try {
            server.close();
        } catch (e) {
            console.error('Error closing server:', e.message);
        }
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
    res.json({ status: 'ok', platform: process.platform });
});

async function start(port = 3000) {
    if (!checkDependencies()) {
        console.log('First run detected, installing dependencies...');
        markInstalled();
    }
    
    console.log(`Starting webhook server on port ${port}...`);
    
    const borePort = await startBoreTunnel(port);
    
    return new Promise((resolve) => {
        server = app.listen(port, '127.0.0.1', () => {
            console.log(`Webhook server ready on bore.pub:${borePort}`);
            console.log(`URL to share: https://bore.pub:${borePort}`);
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
        console.log(`\n========================================`);
        console.log(`Server running! Share this URL with remote:`);
        console.log(`https://bore.pub:${borePort}`);
        console.log(`========================================\n`);
    }).catch(err => {
        console.error('Failed to start:', err.message);
        process.exit(1);
    });
}

module.exports = { start, getCredentials, shutdown, app };
