/*
 *
 *    Copyright IBM Corp. 2023
 *
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3001;
const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:9080';

// MIME types for different file extensions
const mimeTypes = {
    '.html': 'text/html',
    '.js': 'text/javascript',
    '.css': 'text/css',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.ttf': 'font/ttf',
    '.eot': 'application/vnd.ms-fontobject',
    '.otf': 'font/otf'
};

const server = http.createServer((req, res) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);

    // Check if this is an API request
    if (req.url.startsWith('/customers') || req.url.startsWith('/accounts')) {
        // Proxy API requests to backend
        proxyApiRequest(req, res);
        return;
    }

    // Parse URL and strip query parameters
    const urlPath = req.url.split('?')[0];
    let filePath = '.' + urlPath;
    if (filePath === './') {
        filePath = './index.html';
    }

    // Get file extension
    const extname = String(path.extname(filePath)).toLowerCase();
    const contentType = mimeTypes[extname] || 'application/octet-stream';

    // Read and serve file
    fs.readFile(filePath, (error, content) => {
        if (error) {
            if (error.code === 'ENOENT') {
                // File not found - serve 404
                res.writeHead(404, { 'Content-Type': 'text/html' });
                res.end('<h1>404 - File Not Found</h1>', 'utf-8');
            } else {
                // Server error
                res.writeHead(500);
                res.end(`Server Error: ${error.code}`, 'utf-8');
            }
        } else {
            // Success - serve file
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content, 'utf-8');
        }
    });
});

// Proxy API requests to backend
function proxyApiRequest(req, res) {
    const apiUrl = `${API_BASE_URL}${req.url}`;
    console.log(`Proxying API request to: ${apiUrl}`);

    const options = {
        method: req.method,
        headers: {
            'Content-Type': 'application/json',
            ...req.headers
        }
    };

    const proxyReq = http.request(apiUrl, options, (proxyRes) => {
        // Forward status code and headers
        res.writeHead(proxyRes.statusCode, proxyRes.headers);

        // Pipe response back to client
        proxyRes.pipe(res);
    });

    proxyReq.on('error', (error) => {
        console.error('Proxy request failed:', error);
        res.writeHead(502, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Bad Gateway', message: error.message }));
    });

    // Pipe request body to backend
    req.pipe(proxyReq);
}

server.listen(PORT, () => {
    console.log('='.repeat(60));
    console.log('CICS Banking Sample Application - Vanilla JavaScript Frontend');
    console.log('='.repeat(60));
    console.log(`Server running at http://localhost:${PORT}/`);
    console.log(`Press Ctrl+C to stop the server`);
    console.log('='.repeat(60));
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
    console.log('\nSIGTERM signal received: closing HTTP server');
    server.close(() => {
        console.log('HTTP server closed');
    });
});

process.on('SIGINT', () => {
    console.log('\nSIGINT signal received: closing HTTP server');
    server.close(() => {
        console.log('HTTP server closed');
        process.exit(0);
    });
});

// Made with Bob
