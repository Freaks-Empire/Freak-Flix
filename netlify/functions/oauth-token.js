// netlify/functions/oauth-token.js
// Serverless function to exchange OAuth authorization code for tokens
// This avoids CORS issues since the request comes from server-side

exports.handler = async (event) => {
    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
            },
            body: '',
        };
    }

    if (event.httpMethod !== 'POST') {
        return {
            statusCode: 405,
            headers: { 'Access-Control-Allow-Origin': '*' },
            body: JSON.stringify({ error: 'Method not allowed' }),
        };
    }

    try {
        const body = JSON.parse(event.body);
        const { code, code_verifier, redirect_uri, client_id, tenant } = body;

        if (!code || !redirect_uri || !client_id) {
            return {
                statusCode: 400,
                headers: { 'Access-Control-Allow-Origin': '*' },
                body: JSON.stringify({ error: 'Missing required parameters' }),
            };
        }

        const tenantId = tenant || 'common';
        const tokenEndpoint = `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`;

        // Build token request
        const params = new URLSearchParams();
        params.append('client_id', client_id);
        params.append('grant_type', 'authorization_code');
        params.append('code', code);
        params.append('redirect_uri', redirect_uri);

        if (code_verifier) {
            params.append('code_verifier', code_verifier);
        }

        // Exchange code for tokens
        const response = await fetch(tokenEndpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: params.toString(),
        });

        const data = await response.json();

        if (!response.ok) {
            return {
                statusCode: response.status,
                headers: { 'Access-Control-Allow-Origin': '*' },
                body: JSON.stringify({
                    error: data.error || 'token_exchange_failed',
                    error_description: data.error_description || 'Failed to exchange code for tokens',
                }),
            };
        }

        // Return tokens
        return {
            statusCode: 200,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(data),
        };

    } catch (error) {
        console.error('OAuth token exchange error:', error);
        return {
            statusCode: 500,
            headers: { 'Access-Control-Allow-Origin': '*' },
            body: JSON.stringify({
                error: 'server_error',
                error_description: error.message,
            }),
        };
    }
};
