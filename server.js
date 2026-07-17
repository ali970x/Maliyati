const http = require('node:http');
const dns = require('node:dns');
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');

dns.setDefaultResultOrder('ipv4first');

const port = Number(process.env.PORT || 10000);
const staticRoot = path.join(__dirname, 'deploy', 'web');
const maxSheetBytes = 5 * 1024 * 1024;

const contentTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.webp': 'image/webp',
};

function sendJson(response, status, payload) {
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  response.end(JSON.stringify(payload));
}

async function proxySheet(requestUrl, response) {
  const rawTarget = requestUrl.searchParams.get('url');
  if (!rawTarget) {
    sendJson(response, 400, { error: 'Missing Google Sheet URL.' });
    return;
  }

  let target;
  try {
    target = new URL(rawTarget);
  } catch (_) {
    sendJson(response, 400, { error: 'Invalid Google Sheet URL.' });
    return;
  }

  const isAllowed =
    target.protocol === 'https:' &&
    target.hostname === 'docs.google.com' &&
    target.pathname.startsWith('/spreadsheets/');
  if (!isAllowed) {
    sendJson(response, 403, { error: 'Only Google Sheets URLs are allowed.' });
    return;
  }

  try {
    const upstream = await fetch(target, {
      redirect: 'follow',
      signal: AbortSignal.timeout(25000),
      headers: { 'User-Agent': 'Maliyati/1.0' },
    });
    const body = Buffer.from(await upstream.arrayBuffer());
    if (body.length > maxSheetBytes) {
      sendJson(response, 413, { error: 'Google Sheet response is too large.' });
      return;
    }

    response.writeHead(upstream.status, {
      'Content-Type': upstream.headers.get('content-type') ||
        'text/csv; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    });
    response.end(body);
  } catch (error) {
    sendJson(response, 502, {
      error: 'Could not load Google Sheet.',
      detail:
        error && error.cause instanceof Error
          ? error.cause.message
          : error instanceof Error
            ? error.message
            : String(error),
    });
  }
}

function staticFileFor(pathname) {
  let decoded;
  try {
    decoded = decodeURIComponent(pathname);
  } catch (_) {
    return null;
  }
  const requested = decoded === '/' ? '/index.html' : decoded;
  const candidate = path.resolve(staticRoot, `.${requested}`);
  const isInsideStaticRoot =
    candidate === staticRoot || candidate.startsWith(`${staticRoot}${path.sep}`);
  return isInsideStaticRoot ? candidate : null;
}

function serveFile(filePath, request, response) {
  const extension = path.extname(filePath).toLowerCase();
  const fileName = path.basename(filePath);
  const revalidateFiles = new Set([
    '.last_build_id',
    'flutter_bootstrap.js',
    'flutter_service_worker.js',
    'index.html',
    'version.json',
  ]);
  const cacheControl = revalidateFiles.has(fileName) || fileName === 'main.dart.js'
    ? 'no-store, no-cache, must-revalidate'
    : filePath.includes(`${path.sep}canvaskit${path.sep}`)
      ? 'public, max-age=31536000, immutable'
      : 'public, max-age=3600';
  const acceptsBrotli = /\bbr\b/.test(request.headers['accept-encoding'] || '');
  const acceptsGzip = /\bgzip\b/.test(request.headers['accept-encoding'] || '');
  const shouldSkipDynamicCompression = fileName === 'main.dart.js';
  const canCompress =
    !shouldSkipDynamicCompression &&
    new Set(['.css', '.html', '.js', '.json', '.svg']).has(extension);
  const contentEncoding = canCompress && acceptsBrotli
    ? 'br'
    : canCompress && acceptsGzip
      ? 'gzip'
      : null;
  const headers = {
    'Content-Type': contentTypes[extension] || 'application/octet-stream',
    'Cache-Control': cacheControl,
    'X-Content-Type-Options': 'nosniff',
  };
  if (contentEncoding) {
    headers['Content-Encoding'] = contentEncoding;
    headers.Vary = 'Accept-Encoding';
  }
  response.writeHead(200, headers);
  if (request.method === 'HEAD') {
    response.end();
    return;
  }
  const fileStream = fs.createReadStream(filePath);
  if (contentEncoding === 'br') {
    fileStream.pipe(zlib.createBrotliCompress()).pipe(response);
    return;
  }
  if (contentEncoding === 'gzip') {
    fileStream.pipe(zlib.createGzip()).pipe(response);
    return;
  }
  fileStream.pipe(response);
}

const server = http.createServer(async (request, response) => {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    sendJson(response, 405, { error: 'Method not allowed.' });
    return;
  }

  const requestUrl = new URL(request.url, `http://${request.headers.host}`);
  if (requestUrl.pathname === '/api/sheet') {
    await proxySheet(requestUrl, response);
    return;
  }

  const filePath = staticFileFor(requestUrl.pathname);
  if (filePath && fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
    serveFile(filePath, request, response);
    return;
  }

  const indexPath = path.join(staticRoot, 'index.html');
  if (fs.existsSync(indexPath)) {
    serveFile(indexPath, request, response);
    return;
  }
  sendJson(response, 503, { error: 'Web build is not available.' });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Maliyati is listening on port ${port}`);
});
