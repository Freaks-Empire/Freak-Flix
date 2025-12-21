const fetch = require('node-fetch');

exports.handler = async (event, context) => {
    // CORS Preflight
    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
            body: '',
        };
    }

    try {
        // Determine the path to forward to Microsoft
        // The rewrite is /api/ms_auth/* -> /.netlify/functions/ms_auth_proxy
        // Netlify might preserve the original path in event.path or pass the rewritten one.
        // Usually event.path is the invoked function path if rewritten using '200' (proxy), 
        // OR the original path if it's just a raw redirect?
        // Actually, when using `to = "/.netlify/functions/ms_auth_proxy"`, event.path usually becomes the function path.
        // However, we can use the 'path' parameter if we modify the rewrite rule, OR simply parsing the original request if possible.
        // Let's assume the user configures the rewrite as:
        // /api/ms_auth/* -> /.netlify/functions/ms_auth_proxy
        // We can rely on extracting the suffix.

        // Fallback: If we can't easily get the suffix from event.path because it's rewritten,
        // we can rely on the fact that the client app sends requests like:
        // /api/ms_auth/{tenant}/oauth2/v2.0/token

        // So we just look for '/api/ms_auth/' in the path and take everything after.
        // If not found, check if it starts with /.netlify/functions/ms_auth_proxy/ and take after.

        let pathSuffix = '';
        if (event.path.includes('/api/ms_auth/')) {
            pathSuffix = event.path.split('/api/ms_auth/')[1];
        } else if (event.path.includes('/ms_auth_proxy/')) {
            pathSuffix = event.path.split('/ms_auth_proxy/')[1];
        }

        if (!pathSuffix) {
            // If we can't find it (maybe direct invocation without path), default to something safe or error
            return { statusCode: 400, body: 'Invalid path' };
        }

        const targetUrl = `https://login.microsoftonline.com/${pathSuffix}${event.queryStringParameters ? '?' + new URLSearchParams(event.queryStringParameters).toString() : ''}`;

        console.log(`Proxying to: ${targetUrl}`);

        // Filter headers
        const headers = {};
        for (const [key, value] of Object.entries(event.headers)) {
            const k = key.toLowerCase();
            // Forward useful headers, strip problematic ones
            if (['content-type', 'accept', 'authorization'].includes(k)) {
                headers[key] = value;
            }
        }
        // Explicitly do NOT send Origin or Referer to Microsoft
        // headers['User-Agent'] = 'FreakFlix-Proxy/1.0'; // Optional

        const response = await fetch(targetUrl, {
            method: event.httpMethod,
            headers: headers,
            body: event.body ? event.body : undefined,
        });

        const data = await response.text();

        return {
            statusCode: response.status,
            body: data,
            headers: {
                'Content-Type': response.headers.get('content-type') || 'application/json',
                'Access-Control-Allow-Origin': '*', // Allow all origins (browser will see this)
            }
        };

    } catch (error) {
        console.error('Proxy Error:', error);
        return {
            statusCode: 502,
            body: JSON.stringify({ error: 'Proxy Request Failed', details: error.toString() }),
        };
    }
};
