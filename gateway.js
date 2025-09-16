// gateway.js — proxy + auth (bez require('json-server'))
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const { createProxyMiddleware } = require('http-proxy-middleware');
const fs = require('fs');
const path = require('path');

// dynamiczny import node-fetch (działa w CJS)
const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3100;
const UPSTREAM = process.env.UPSTREAM || 'http://127.0.0.1:3000';
const JWT_SECRET = process.env.JWT_SECRET || 'change_me';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin';

// ───────────── Trwałe hasło admina (.admin.json) ─────────────
const ADMIN_STORE = path.join(__dirname, '.admin.json');
let adminPasswordHash = null;

function safeReadJson(file) {
  try {
    if (!fs.existsSync(file)) return null;
    const txt = fs.readFileSync(file, 'utf8').trim();
    if (!txt) return null;
    return JSON.parse(txt);
  } catch {
    return null;
  }
}

(async () => {
  try {
    const data = safeReadJson(ADMIN_STORE);
    if (data && data.passwordHash) {
      adminPasswordHash = data.passwordHash;
      console.log('✓ Admin password loaded from .admin.json');
    } else {
      const hash = await bcrypt.hash(ADMIN_PASSWORD, 10);
      fs.writeFileSync(ADMIN_STORE, JSON.stringify({ passwordHash: hash }, null, 2), 'utf8');
      adminPasswordHash = hash;
      console.log('✓ Admin password initialized from .env and saved to .admin.json');
    }
  } catch (e) {
    console.error('Admin password init error (fallback to .env):', e);
    adminPasswordHash = await bcrypt.hash(ADMIN_PASSWORD, 10);
  }
})();


// ───────────── Auth helpers (MUSZĄ BYĆ PRZED ROUTAMI) ─────────────
function issueToken() {
  return jwt.sign({ role: 'admin' }, JWT_SECRET, { expiresIn: '12h' });
}

function authMiddleware(req, res, next) {
  const h = req.headers.authorization || '';
  const [, token] = h.split(' ');
  if (!token) return res.status(401).json({ error: 'No token' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

// ───────────── ROUTES: AUTH ─────────────
app.post('/auth/login', async (req, res) => {
  const { password } = req.body || {};
  if (!password) return res.status(400).json({ error: 'Missing password' });
  const ok = await bcrypt.compare(password, adminPasswordHash);
  if (!ok) return res.status(401).json({ error: 'Bad credentials' });
  return res.json({ token: issueToken() });
});

// ZMIANA HASŁA (wymaga tokena)
app.post('/auth/change-password', authMiddleware, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body || {};
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Missing currentPassword/newPassword' });
    }
    if (typeof newPassword !== 'string' || newPassword.length < 8) {
      return res.status(400).json({ error: 'New password must be at least 8 characters' });
    }
    const ok = await bcrypt.compare(currentPassword, adminPasswordHash);
    if (!ok) return res.status(401).json({ error: 'Current password is incorrect' });

    const newHash = await bcrypt.hash(newPassword, 10);
    fs.writeFileSync(ADMIN_STORE, JSON.stringify({ passwordHash: newHash }, null, 2), 'utf8');
    adminPasswordHash = newHash;

    return res.status(200).json({ success: true });
  } catch (e) {
    console.error('change-password error', e);
    return res.status(500).json({ error: 'Change password failed' });
  }
});

// ───────────── Walidacje ─────────────
async function hasActiveShift(employeeId) {
  const r = await fetch(`${UPSTREAM}/shifts?employee_id=${employeeId}&ended_at=null`);
  if (!r.ok) return false;
  const list = await r.json();
  return Array.isArray(list) && list.length > 0;
}

async function validateShiftStart(req, res, next) {
  try {
    if (req.method !== 'POST' || !req.path.startsWith('/shifts')) return next();
    const body = req.body || {};
    if (!body.employee_id || !body.started_at) return next();
    const active = await hasActiveShift(body.employee_id);
    if (active && (body.ended_at == null)) {
      return res.status(400).json({ error: 'Employee already has an active shift.' });
    }
    next();
  } catch (e) {
    console.error('validateShiftStart error', e);
    next();
  }
}

async function validateEmployeePin(req, res, next) {
  try {
    if (!req.path.startsWith('/employees') || !['POST', 'PATCH', 'PUT'].includes(req.method)) {
      return next();
    }
    const body = req.body || {};
    if (!body.pin) return next();

    const r = await fetch(`${UPSTREAM}/employees?pin=${encodeURIComponent(body.pin)}`);
    const list = await r.json();

    if (req.method === 'PATCH' || req.method === 'PUT') {
      const m = req.path.match(/^\/employees\/(.+)$/);
      const currentId = m ? m[1] : null;
      const dup = Array.isArray(list) ? list.find(e => String(e.id) !== String(currentId)) : null;
      if (dup) return res.status(400).json({ error: 'PIN already used' });
    } else {
      if (Array.isArray(list) && list.length > 0) {
        return res.status(400).json({ error: 'PIN already used' });
      }
    }
    next();
  } catch (e) {
    console.error('validateEmployeePin error', e);
    next();
  }
}

// ───────────── Publiczne (bez tokena) ─────────────
app.get('/employees', createProxyMiddleware({ target: UPSTREAM, changeOrigin: true }));
app.get('/employees/:id', createProxyMiddleware({ target: UPSTREAM, changeOrigin: true }));

// ───────────── Chronione proxy ─────────────
app.use('/shifts', authMiddleware, validateShiftStart, createProxyMiddleware({
  target: UPSTREAM, changeOrigin: true,
}));
app.use('/employees', authMiddleware, validateEmployeePin, createProxyMiddleware({
  target: UPSTREAM, changeOrigin: true,
}));
app.use('/absences', authMiddleware, createProxyMiddleware({
  target: UPSTREAM, changeOrigin: true,
}));
app.use('/roles', authMiddleware, createProxyMiddleware({
  target: UPSTREAM, changeOrigin: true,
}));
app.use('/work_shifts', authMiddleware, createProxyMiddleware({
  target: UPSTREAM, changeOrigin: true,
}));

app.listen(PORT, () => {
  console.log(`✓ Gateway on http://0.0.0.0:${PORT} -> ${UPSTREAM}`);
});
