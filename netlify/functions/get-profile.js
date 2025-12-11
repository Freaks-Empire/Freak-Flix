const { Pool } = require('pg');

const connectionString =
  process.env.NETLIFY_DB_CONNECTION ||
  process.env.NETLIFY_DB_CONNECTION_STRING ||
  process.env.NETLIFY_DATABASE_URL ||
  process.env.NETLIFY_DATABASE_URL_UNPOOLED ||
  process.env.DATABASE_URL;

const pool = connectionString ? new Pool({ connectionString, max: 1 }) : null;

exports.handler = async (event, context) => {
  if (!pool) {
    return { statusCode: 500, body: 'Database not configured' };
  }

  const identity = context.clientContext && context.clientContext.identity;
  if (!identity || !identity.url || !identity.token) {
    return { statusCode: 401, body: 'Unauthorized' };
  }

  const identityId = identity.sub || identity.user || identity.id;
  const email = identity.email;
  if (!identityId) {
    return { statusCode: 401, body: 'Invalid identity token' };
  }

  try {
    const result = await pool.query(
      'SELECT id, identity_id, email, display_name, metadata, created_at FROM identity_users WHERE identity_id = $1 LIMIT 1',
      [identityId],
    );
    if (result.rows.length === 0) {
      return { statusCode: 404, body: 'Profile not found' };
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        profile: result.rows[0],
        identity: { id: identityId, email },
      }),
    };
  } catch (err) {
    console.error(err);
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
};
