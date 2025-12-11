const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const connectionString =
  process.env.NETLIFY_DB_CONNECTION ||
  process.env.NETLIFY_DB_CONNECTION_STRING ||
  process.env.NETLIFY_DATABASE_URL ||
  process.env.NETLIFY_DATABASE_URL_UNPOOLED;

const jwtSecret = process.env.JWT_SECRET;
const jwtExpiry = process.env.JWT_EXPIRY || '7d';

if (!connectionString) {
  console.warn('Missing NETLIFY_DB_CONNECTION / NETLIFY_DB_CONNECTION_STRING');
}

const pool = connectionString
  ? new Pool({ connectionString, max: 1 })
  : null;

async function ensureTable() {
  if (!pool) return;
  await pool.query(`
    CREATE TABLE IF NOT EXISTS app_users (
      id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
  `);
}

async function registerUser(email, password) {
  await ensureTable();
  const hash = await bcrypt.hash(password, 10);
  const result = await pool.query(
    'INSERT INTO app_users (email, password_hash) VALUES ($1, $2) RETURNING id, email, created_at',
    [email, hash],
  );
  return result.rows[0];
}

async function loginUser(email, password) {
  await ensureTable();
  const result = await pool.query(
    'SELECT id, email, password_hash, created_at FROM app_users WHERE email = $1 LIMIT 1',
    [email],
  );
  if (result.rows.length === 0) return null;
  const user = result.rows[0];
  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) return null;
  return { id: user.id, email: user.email, created_at: user.created_at };
}

function issueToken(user) {
  if (!jwtSecret) {
    throw new Error('JWT_SECRET not set');
  }
  return jwt.sign(
    { sub: user.id, email: user.email },
    jwtSecret,
    { expiresIn: jwtExpiry },
  );
}

function verifyToken(token) {
  if (!jwtSecret) {
    throw new Error('JWT_SECRET not set');
  }
  return jwt.verify(token, jwtSecret);
}

exports.handler = async (event) => {
  if (!pool) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Database not configured on server' }),
    };
  }

  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  let payload = {};
  try {
    payload = JSON.parse(event.body || '{}');
  } catch (_) {
    return { statusCode: 400, body: 'Invalid JSON' };
  }

  const action = payload.action || event.queryStringParameters?.action;
  const email = (payload.email || '').trim().toLowerCase();
  const password = payload.password || '';
  const authHeader = event.headers?.authorization || '';
  const bearerToken = authHeader.startsWith('Bearer ')
    ? authHeader.substring('Bearer '.length)
    : payload.token || event.queryStringParameters?.token;

  try {
    if (action === 'register') {
      if (!email || !password) {
        return {
          statusCode: 400,
          body: JSON.stringify({ error: 'email and password are required' }),
        };
      }
      const user = await registerUser(email, password);
      const token = issueToken(user);
      return { statusCode: 200, body: JSON.stringify({ user, token }) };
    }

    if (action === 'login') {
        if (!email || !password) {
          return {
            statusCode: 400,
            body: JSON.stringify({ error: 'email and password are required' }),
          };
        }
      const user = await loginUser(email, password);
      if (!user) {
        return { statusCode: 401, body: JSON.stringify({ error: 'Invalid credentials' }) };
      }
      const token = issueToken(user);
      return { statusCode: 200, body: JSON.stringify({ user, token }) };
    }

    if (action === 'me') {
      if (!bearerToken) {
        return { statusCode: 401, body: JSON.stringify({ error: 'Missing token' }) };
      }
      const decoded = verifyToken(bearerToken);
      return { statusCode: 200, body: JSON.stringify({ user: decoded }) };
    }

    return { statusCode: 400, body: JSON.stringify({ error: 'Unsupported action' }) };
  } catch (err) {
    console.error(err);
    if (err.message === 'JWT_SECRET not set') {
      return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
    }
    const message = err.code === '23505' ? 'Email already exists' : 'Server error';
    return { statusCode: 500, body: JSON.stringify({ error: message }) };
  }
};
