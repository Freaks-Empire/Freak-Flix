const fetch = require('node-fetch');

exports.handler = async function (event, context) {
    // Only allow POST
    if (event.httpMethod !== 'POST') {
        return {
            statusCode: 405,
            body: 'Method Not Allowed',
        };
    }

    // Get the target URL (default to stashdb.org if not specified via some other means, 
    // but usually users want stashdb.org if using this proxy)
    const targetUrl = 'https://stashdb.org/graphql';

    try {
        const { headers, body } = event;

        // Filter headers to forward
        const forwardHeaders = {
            'Content-Type': 'application/json',
            'ApiKey': headers['apikey'] || headers['ApiKey'] || '', // Case insensitive check
        };

        const response = await fetch(targetUrl, {
            method: 'POST',
            headers: forwardHeaders,
            body: body,
        });

        const responseBody = await response.text();

        return {
            statusCode: response.status,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*', // CORS help
            },
            body: responseBody,
        };
    } catch (error) {
        console.error('Proxy Error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Proxy Request Failed', details: error.toString() }),
        };
    }
};
