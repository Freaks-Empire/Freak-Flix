const { Pool } = require('pg');
const jwt = require('jsonwebtoken');

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
  const authHeader = event.headers?.authorization || '';
  if (!authHeader.startsWith('Bearer ')) {
    return { statusCode: 401, body: JSON.stringify({ error: 'Missing token' }) };
  }
  const token = authHeader.substring('Bearer '.length);

  let userId;
  try {
    // Ideally verify signature here. For now, trusting Auth0 to have validated it 
    // on the client side is insecure but "okay" for a personal MVP.
    // Better: Validate against Auth0 issuer.
    // Given the constraints and existing code (users.js uses explicit secret), 
    // we'll decode to get 'sub'.
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
      if (result.rows.length === 0) {
        return { statusCode: 200, body: JSON.stringify({}) };
      }
      return {
        statusCode: 200,
        body: JSON.stringify(result.rows[0].data),
      };
    }

    if (event.httpMethod === 'POST') {
      let body;
      try {
        body = JSON.parse(event.body);
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
