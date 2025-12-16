const { Pool } = require('pg');
const jwt = require('jsonwebtoken');
const zlib = require('zlib');

const connectionString =
  process.env.NETLIFY_DB_CONNECTION ||
  process.env.NETLIFY_DB_CONNECTION_STRING ||
  process.env.NETLIFY_DATABASE_URL ||
  process.env.NETLIFY_DATABASE_URL_UNPOOLED;

const pool = connectionString
  ? new Pool({ connectionString, max: 1 })
  : null;

async function ensureTable() {
  if (!pool) return;
  await pool.query(`
    CREATE TABLE IF NOT EXISTS user_data (
      user_id TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );
  `);
}

exports.handler = async (event) => {
  if (!pool) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Database not configured' }),
    };
  }

  // 1. Authenticate Request
  // Headers are case-insensitive in Netlify? Usually normalized to lowercase keys.
  // Accessing event.headers directly might be case-sensitive depending on env.
  // We'll try lowercase lookup.
  const headers = {};
  for (const k in event.headers) {
    headers[k.toLowerCase()] = event.headers[k];
  }

  const authHeader = headers['authorization'] || '';
  if (!authHeader.startsWith('Bearer ')) {
    return { statusCode: 401, body: JSON.stringify({ error: 'Missing token' }) };
  }
  const token = authHeader.substring('Bearer '.length);

  let userId;
  try {
    const decoded = jwt.decode(token);
    if (!decoded || !decoded.sub) {
      return { statusCode: 401, body: JSON.stringify({ error: 'Invalid token payload' }) };
    }
    userId = decoded.sub;
  } catch (e) {
    return { statusCode: 401, body: JSON.stringify({ error: 'Token parse error' }) };
  }

  try {
    await ensureTable();

    if (event.httpMethod === 'GET') {
      const result = await pool.query(
        'SELECT data FROM user_data WHERE user_id = $1',
        [userId]
      );

      const data = result.rows.length > 0 ? result.rows[0].data : {};
      const jsonStr = JSON.stringify(data);

      // Check for gzip support
      const acceptEncoding = headers['accept-encoding'] || '';
      if (acceptEncoding.includes('gzip')) {
        const compressed = zlib.gzipSync(jsonStr);
        return {
          statusCode: 200,
          headers: {
            'Content-Type': 'application/json',
            'Content-Encoding': 'gzip',
          },
          body: compressed.toString('base64'),
          isBase64Encoded: true,
        };
      } else {
        return {
          statusCode: 200,
          headers: { 'Content-Type': 'application/json' },
          body: jsonStr,
        };
      }
    }

    if (event.httpMethod === 'POST') {
      let rawBody = event.body;

      // Handle Base64 encoding (Netlify often base64 encodes binary or sometimes text)
      if (event.isBase64Encoded) {
        rawBody = Buffer.from(event.body, 'base64');
      }

      // Handle Gzip
      const contentEncoding = headers['content-encoding'] || '';
      if (contentEncoding === 'gzip') {
        try {
          // If rawBody is a string here, Buffer.from might handle it if not base64'd above
          if (typeof rawBody === 'string') {
            rawBody = Buffer.from(rawBody); // Should match encoding
          }
          rawBody = zlib.gunzipSync(rawBody).toString('utf-8');
        } catch (err) {
          return { statusCode: 400, body: JSON.stringify({ error: 'Decompression failed', details: err.message }) };
        }
      }

      let body;
      try {
        body = JSON.parse(rawBody.toString());
      } catch (_) {
        return { statusCode: 400, body: JSON.stringify({ error: 'Invalid JSON' }) };
      }

      // Upsert
      await pool.query(
        `INSERT INTO user_data (user_id, data, updated_at)
         VALUES ($1, $2, NOW())
         ON CONFLICT (user_id) 
         DO UPDATE SET data = $2, updated_at = NOW()`,
        [userId, body]
      );

      return { statusCode: 200, body: JSON.stringify({ success: true }) };
    }

    return { statusCode: 405, body: 'Method Not Allowed' };

  } catch (err) {
    console.error(err);
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
};
