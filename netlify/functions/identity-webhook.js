const { Pool } = require('pg');

const connectionString =
  process.env.NETLIFY_DB_CONNECTION ||
  process.env.NETLIFY_DB_CONNECTION_STRING ||
  process.env.NETLIFY_DATABASE_URL ||
  process.env.NETLIFY_DATABASE_URL_UNPOOLED ||
  process.env.DATABASE_URL;

const pool = connectionString ? new Pool({ connectionString, max: 1 }) : null;

async function ensureTable() {
  if (!pool) return;
  await pool.query(`
    CREATE TABLE IF NOT EXISTS identity_users (
      id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
      identity_id TEXT NOT NULL UNIQUE,
      email TEXT NOT NULL UNIQUE,
      display_name TEXT,
      metadata JSONB DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
  `);
}

exports.handler = async (event) => {
  if (!pool) {
    return { statusCode: 500, body: 'Database not configured' };
  }

  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  let payload;
  try {
    payload = JSON.parse(event.body || '{}');
  } catch (e) {
    return { statusCode: 400, body: 'Invalid JSON' };
  }

  const identityEvent = payload.event || payload.trigger || '';
  const user = payload.user || payload.body || {};
  const identityId = user.id;
  const email = user.email;
  const displayName =
    user?.user_metadata?.full_name ||
    user?.user_metadata?.name ||
    user?.user_metadata?.display_name ||
    null;
  const metadata = user.user_metadata || {};

  if (!identityId || !email) {
    return { statusCode: 400, body: 'Missing user id/email' };
  }

  if (!['signup', 'confirmed', 'invite', 'login'].includes(identityEvent)) {
    return { statusCode: 200, body: 'Ignored event' };
  }

  try {
    await ensureTable();
    const result = await pool.query(
      `INSERT INTO identity_users (identity_id, email, display_name, metadata)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (identity_id) DO UPDATE
         SET email = EXCLUDED.email,
             display_name = COALESCE(EXCLUDED.display_name, identity_users.display_name),
             metadata = EXCLUDED.metadata
       RETURNING id, identity_id, email, display_name;`,
      [identityId, email, displayName, metadata]
    );

    return {
      statusCode: 200,
      body: JSON.stringify({ ok: true, user: result.rows[0] }),
    };
  } catch (err) {
    console.error(err);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'DB error', detail: err.message }),
    };
  }
};
