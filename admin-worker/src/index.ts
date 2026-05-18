// 堆柴 Admin - Cloudflare Worker
import indexHtml from './index.html';

export default {
  async fetch(request) {
    const url = new URL(request.url);
    
    // Serve admin HTML
    if (url.pathname === '/' || url.pathname === '/index.html') {
      return new Response(indexHtml, {
        headers: {
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'no-cache, no-store',
        },
      });
    }

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Access-Control-Max-Age': '86400',
        },
      });
    }

    // Proxy API calls to main API
    if (url.pathname.startsWith('/api/')) {
      const apiUrl = 'https://api.duichai.com' + url.pathname + url.search;
      const apiRequest = new Request(apiUrl, {
        method: request.method,
        headers: request.headers,
        body: request.body,
      });
      const response = await fetch(apiRequest);
      const h = new Headers(response.headers);
      h.set('Access-Control-Allow-Origin', '*');
      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: h,
      });
    }

    return new Response('Not Found', { status: 404 });
  },
};
