import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { jwt } from 'hono/jwt';
import { SignJWT, importJWK } from 'jose';
import * as bcrypt from 'bcryptjs';

// --- Types ---
type Bindings = {
    DB: D1Database;
    JWT_SECRET: string;
};

const app = new Hono<{ Bindings: Bindings }>();

// --- Middleware ---
app.use('*', cors());

// --- Auth Routes ---

app.post('/auth/register', async (c) => {
    const { email, password } = await c.req.json();
    if (!email || !password) return c.json({ error: 'Missing fields' }, 400);

    const id = crypto.randomUUID();
    const hash = await bcrypt.hash(password, 10);

    try {
        await c.env.DB.prepare(
            'INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)'
        ).bind(id, email, hash).run();
    } catch (e: any) {
        if (e.message.includes('UNIQUE')) {
            return c.json({ error: 'Email already exists' }, 400);
        }
        return c.json({ error: 'DB Error' }, 500);
    }

    return c.json({ ok: true, id, email });
});

app.post('/auth/login', async (c) => {
    const { email, password } = await c.req.json();
    const user = await c.env.DB.prepare(
        'SELECT * FROM users WHERE email = ?'
    ).bind(email).first();

    if (!user) return c.json({ error: 'Invalid credentials' }, 401);

    // @ts-ignore
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) return c.json({ error: 'Invalid credentials' }, 401);

    // Issue Token
    const secret = new TextEncoder().encode(c.env.JWT_SECRET || 'dev-secret-very-insecure');
    const token = await new SignJWT({ sub: user.id, email: user.email })
        .setProtectedHeader({ alg: 'HS256' })
        .setExpirationTime('7d')
        .sign(secret);

    return c.json({
        token,
        user: { id: user.id, email: user.email, created_at: user.created_at }
    });
});

// --- Protected Routes ---
// Simple middleware to verify JWT manually or use Hono's
const authMiddleware = async (c: any, next: any) => {
    const auth = c.req.header('Authorization');
    if (!auth) return c.json({ error: 'Unauthorized' }, 401);
    const token = auth.replace('Bearer ', '');
    try {
        const secret = new TextEncoder().encode(c.env.JWT_SECRET || 'dev-secret-very-insecure');
        // Simple 3-part check or use jose verify
        const { payload } = await import('jose').then(m => m.jwtVerify(token, secret));
        c.set('jwtPayload', payload);
        await next();
    } catch (e) {
        return c.json({ error: 'Invalid Token' }, 401);
    }
};

app.get('/auth/me', authMiddleware, (c) => {
    const payload = c.get('jwtPayload');
    return c.json({ user: payload });
});

// --- Proxy ---
// Replacing ms_auth_proxy.js
app.all('/microsoft/proxy/*', async (c) => {
    // Expected path: /microsoft/proxy/<rest>
    // e.g. /microsoft/proxy/common/oauth2/v2.0/token
    const path = c.req.path.replace('/microsoft/proxy/', '');
    const url = `https://login.microsoftonline.com/${path}${c.req.url.includes('?') ? '?' + c.req.url.split('?')[1] : ''}`;

    const headers = new Headers();
    if (c.req.header('Content-Type')) headers.set('Content-Type', c.req.header('Content-Type')!);

    // Some headers from client might be problematic, simplified forwarding.
    const method = c.req.method;
    const body = ['GET', 'HEAD'].includes(method) ? undefined : await c.req.text();

    const resp = await fetch(url, {
        method,
        headers,
        body
    });

    const respBody = await resp.text();
    return c.body(respBody, resp.status as any, {
        'Content-Type': resp.headers.get('content-type') || 'application/json'
    });
});

// --- Library ---

// 1. Trigger Scan
app.post('/library/scan', authMiddleware, async (c) => {
    const { folderId, accessToken, path, provider } = await c.req.json();
    const user = c.get('jwtPayload');

    if (!accessToken) return c.json({ error: 'Access Token required' }, 400);

    // Upsert Folder
    const dbFolderId = crypto.randomUUID();
    // Logic: check if folder exists for user/path? Or just always add?
    // User wants "clean start" so maybe simpler.
    // Let's check uniqueness by path + user
    const existing = await c.env.DB.prepare(
        'SELECT id FROM library_folders WHERE user_id = ? AND path = ?'
    ).bind(user.sub, path).first();

    let targetId = existing ? existing.id : dbFolderId;

    if (!existing) {
        await c.env.DB.prepare(
            'INSERT INTO library_folders (id, user_id, path, provider, provider_id) VALUES (?, ?, ?, ?, ?)'
        ).bind(targetId, user.sub, path, provider || 'onedrive', folderId).run();
    }

    // Trigger Background Scan via waitUntil (Free Plan compatible)
    // Note: This effectively runs in the background for this request.
    // Cloudflare limits CPU time to 10ms for Free, but I/O wait is ignored in wall time.
    c.executionCtx.waitUntil(
        scanRecursive(accessToken, folderId, user.sub as string, targetId as string, c.env)
    );

    return c.json({ ok: true, status: 'scanning_background', folderId: targetId });
});

// 2. Poll for items
app.get('/library/items', authMiddleware, async (c) => {
    const user = c.get('jwtPayload');
    const { results } = await c.env.DB.prepare(
        'SELECT * FROM media_items WHERE user_id = ? ORDER BY created_at DESC'
    ).bind(user.sub).all();
    return c.json({ items: results });
});

export default app;

// --- Scanning Logic ---

async function scanRecursive(token: string, itemId: string, userId: string, dbFolderId: string, env: Bindings) {
    let url = `https://graph.microsoft.com/v1.0/me/drive/items/${itemId}/children?$select=id,name,file,folder,size,webUrl,mimeType,@microsoft.graph.downloadUrl`;

    // Safety: limit recursion depth or item count to prevent timeouts on free plan?
    // For now, infinite loop until done.

    while (url) {
        const resp = await fetch(url, {
            headers: { 'Authorization': `Bearer ${token}` }
        });

        if (!resp.ok) {
            console.error(`Graph API Error: ${resp.status} ${await resp.text()}`);
            break;
        }

        const data: any = await resp.json();
        const items = data.value || [];

        for (const item of items) {
            if (item.folder) {
                // Recursive!
                await scanRecursive(token, item.id, userId, dbFolderId, env);
            } else if (item.file) {
                // It's a file
                const mime = item.mimeType || '';
                if (mime.startsWith('video/') || item.name.match(/\.(mp4|mkv|avi|webm)$/i)) {
                    // Insert into DB
                    // Note: downloadUrl expires. 
                    const downloadUrl = item['@microsoft.graph.downloadUrl'] || '';

                    try {
                        await env.DB.prepare(`
                            INSERT INTO media_items (id, user_id, folder_id, title, filename, size_bytes, mime_type, provider_item_id, download_url)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                            ON CONFLICT(id) DO NOTHING 
                         `).bind(
                            crypto.randomUUID(),
                            userId,
                            dbFolderId,
                            item.name, // Title default to filename
                            item.name,
                            item.size,
                            item.mimeType,
                            item.id,
                            downloadUrl
                        ).run();
                    } catch (e) {
                        console.error('DB Insert Error', e);
                    }
                }
            }
        }

        url = data['@odata.nextLink']; // Pagination
    }
}
