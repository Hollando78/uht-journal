#!/usr/bin/env node
// Read-only proxy for SurrealDB graph queries.
// Only allows SELECT statements. Rejects all write operations.

const http = require('http');

const SURREAL_URL = 'http://127.0.0.1:8787/sql';
const AUTH = 'Basic ' + Buffer.from('root:uht-research-graph').toString('base64');
const PORT = 8788;
const MAX_BODY = 4096;

const BLOCKED = /\b(INSERT|UPDATE|DELETE|CREATE|REMOVE|DEFINE|RELATE|DROP|UPSERT|KILL|ALTER|THROW|SLEEP|IF\b.*\bTHEN)\b/i;

const server = http.createServer((req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', 'https://journal.universalhex.org');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.method !== 'POST') {
    res.writeHead(405, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Method not allowed' }));
    return;
  }

  let body = '';
  req.on('data', chunk => {
    body += chunk;
    if (body.length > MAX_BODY) {
      res.writeHead(413, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Query too large' }));
      req.destroy();
    }
  });

  req.on('end', () => {
    // Validate: only SELECT allowed
    if (BLOCKED.test(body)) {
      res.writeHead(403, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Write operations not permitted' }));
      return;
    }

    // Forward to SurrealDB
    const proxyReq = http.request(SURREAL_URL, {
      method: 'POST',
      headers: {
        'Authorization': AUTH,
        'Accept': 'application/json',
        'Content-Type': 'text/plain',
        'surreal-ns': 'uht',
        'surreal-db': 'research',
      },
    }, proxyRes => {
      res.writeHead(proxyRes.statusCode, { 'Content-Type': 'application/json' });
      proxyRes.pipe(res);
    });

    proxyReq.on('error', err => {
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Database unavailable' }));
    });

    proxyReq.write(body);
    proxyReq.end();
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Graph proxy listening on 127.0.0.1:${PORT}`);
});
