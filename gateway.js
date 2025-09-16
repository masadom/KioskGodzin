// gateway.js
// Kiosk rejestracji czasu – lekki backend API (Express + plikowa "baza")
// JSON-only: brak HTML'owych odpowiedzi na /api (404/500 również w JSON)

require('dotenv').config();

const path = require('path');
const fs = require('fs');
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const app = express();

// ====== Konfiguracja ======
const PORT = Number(process.env.PORT || 3000);
const JWT_SECRET = process.env.JWT_SECRET || 'change-me-in-.env';
const DB_PATH = path.join(__dirname, 'db.json');
const ADMIN_PATH = path.join(__dirname, '.admin.json');

// ====== Narzędzia plikowe (bezpieczne JSON) ======
function readJsonSafe(filePath, fallback = {}) {
  try {
    if (!fs.existsSync(filePath)) return fallback;
    const raw = fs.readFileSync(filePath, 'utf8').trim();
    if (!raw) return fallback;
    return JSON.parse(raw);
  } catch (e) {
    console.warn(`readJsonSafe(${path.basename(filePath)}): ${e.message}`);
    return fallback;
  }
}

function writeJsonSafe(filePath, dataObj) {
    // zapis atomowy
    const tmp = `${filePath}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(dataObj, null, 2), 'utf8');
    fs.renameSync(tmp, filePath);
}

// ====== Inicjalizacja bazy ======
function ensureDb() {
  const db = readJsonSafe(DB_PATH, null);
  if (!db || typeof db !== 'object') {
    const seed = {
      employees: [],      // { id, name, cardUid, active }
      events: [],         // { id, employeeId, type:'in'|'out', ts }
      nextEmployeeId: 1,
      nextEventId: 1
    };
    writeJsonSafe(DB_PATH, seed);
    return seed;
  }
  // Dopelnij brakujące pola po starych wersjach
  db.employees ||= [];
  db.events ||= [];
  db.nextEmployeeId = Number.isInteger(db.nextEmployeeId) ? db.nextEmployeeId : 1;
  db.nextEventId = Number.isInteger(db.nextEventId) ? db.nextEventId : 1;
  return db;
}

function ensureAdmin() {
  const adm = readJsonSafe(ADMIN_PATH, null);
  if (!adm || !adm.passwordHash) {
    const init = { passwordHash: '', updatedAt: new Date().toISOString() };
    const initPw = process.env.ADMIN_INIT_PASSWORD;
    if (initPw && initPw.length >= 4) {
      init.passwordHash = bcrypt.hashSync(initPw, 10);
      console.log('[admin] Utworzono haslo admina z ADMIN_INIT_PASSWORD (.env).');
    } else {
      // Jeśli nie podano hasła: ustaw "admin" (tylko na dev) i ostrzeż
      init.passwordHash = bcrypt.hashSync('admin', 10);
      console.warn('[admin] Brak ADMIN_INIT_PASSWORD – ustawiono tymczasowe haslo "admin". Zmien w panelu natychmiast!');
    }
    writeJsonSafe(ADMIN_PATH, init);
    return init;
  }
  return adm;
}

let DB = ensureDb();
let ADMIN = ensureAdmin();

// ====== Middleware globalne ======
app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(morgan('tiny'));

// Wymuś JSON dla wszystkich odpowiedzi pod /api (także 404/500)
app.use('/api', (req, res, next) => {
  res.type('application/json; charset=utf-8');
  next();
});
// JSON-only również pod /admin (alias dla starszych/innnych zakładek frontu)
app.use('/admin', (req, res, next) => {
  res.type('application/json; charset=utf-8');
  next();
});




// ====== Helpery ======
function signToken(payload, expiresIn = '2d') {
  return jwt.sign(payload, JWT_SECRET, { expiresIn });
}

function authMiddleware(req, res, next) {
  try {
    const hdr = req.headers['authorization'] || '';
    const token = hdr.startsWith('Bearer ') ? hdr.slice(7) : null;
    if (!token) return res.status(401).json({ ok: false, error: 'Unauthorized' });
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    return next();
  } catch (e) {
    return res.status(401).json({ ok: false, error: 'Unauthorized' });
  }
}

function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ ok: false, error: 'Forbidden' });
  }
  next();
}

// ====== API – zdrowie ======
app.get('/api/ping', (req, res) => {
  res.status(200).json({ ok: true, time: new Date().toISOString() });
});

// ====== API – Admin: login, zmiana hasla ======
app.post('/api/admin/login', (req, res) => {
  const { password } = req.body || {};
  if (typeof password !== 'string' || !password.length) {
    return res.status(400).json({ ok: false, error: 'PasswordRequired' });
  }
  ADMIN = readJsonSafe(ADMIN_PATH, ADMIN);
  const valid = bcrypt.compareSync(password, ADMIN.passwordHash || '');
  if (!valid) {
    return res.status(401).json({ ok: false, error: 'InvalidCredentials' });
  }
  const token = signToken({ role: 'admin' }, '8h');
  res.status(200).json({ ok: true, token });
});

app.post('/api/admin/password', authMiddleware, requireAdmin, (req, res) => {
  const { currentPassword, newPassword } = req.body || {};
  if (!newPassword || String(newPassword).length < 4) {
    return res.status(400).json({ ok: false, error: 'WeakPassword', message: 'Min 4 znaki.' });
  }
  ADMIN = readJsonSafe(ADMIN_PATH, ADMIN);
  const valid = bcrypt.compareSync(currentPassword || '', ADMIN.passwordHash || '');
  if (!valid) return res.status(401).json({ ok: false, error: 'InvalidCredentials' });

  ADMIN.passwordHash = bcrypt.hashSync(String(newPassword), 10);
  ADMIN.updatedAt = new Date().toISOString();
  writeJsonSafe(ADMIN_PATH, ADMIN);
  res.status(200).json({ ok: true });
});

// ====== API – Admin: pracownicy CRUD ======
app.get('/api/admin/employees', authMiddleware, requireAdmin, (req, res) => {
  DB = readJsonSafe(DB_PATH, DB);
  res.status(200).json({
    ok: true,
    data: DB.employees.map(e => ({
      id: e.id,
      name: e.name,
      cardUid: e.cardUid,
      active: e.active !== false
    }))
  });
});

app.post('/api/admin/employees', authMiddleware, requireAdmin, (req, res) => {
  const { name, cardUid, active = true } = req.body || {};
  if (!name || !cardUid) {
    return res.status(400).json({ ok: false, error: 'ValidationError', message: 'Wymagane: name, cardUid' });
  }
  DB = readJsonSafe(DB_PATH, DB);
  const exists = DB.employees.find(e => e.cardUid === String(cardUid));
  if (exists) return res.status(409).json({ ok: false, error: 'CardUidExists' });

  const emp = {
    id: DB.nextEmployeeId++,
    name: String(name),
    cardUid: String(cardUid),
    active: !!active
  };
  DB.employees.push(emp);
  writeJsonSafe(DB_PATH, DB);
  res.status(201).json({ ok: true, data: emp });
});

app.put('/api/admin/employees/:id', authMiddleware, requireAdmin, (req, res) => {
  const id = Number(req.params.id);
  const { name, cardUid, active } = req.body || {};
  DB = readJsonSafe(DB_PATH, DB);

  const idx = DB.employees.findIndex(e => e.id === id);
  if (idx === -1) return res.status(404).json({ ok: false, error: 'NotFound' });

  if (cardUid) {
    const dup = DB.employees.find(e => e.cardUid === String(cardUid) && e.id !== id);
    if (dup) return res.status(409).json({ ok: false, error: 'CardUidExists' });
  }

  const emp = DB.employees[idx];
  if (typeof name === 'string') emp.name = name;
  if (typeof cardUid === 'string') emp.cardUid = cardUid;
  if (typeof active === 'boolean') emp.active = active;
  DB.employees[idx] = emp;

  writeJsonSafe(DB_PATH, DB);
  res.status(200).json({ ok: true, data: emp });
});

app.delete('/api/admin/employees/:id', authMiddleware, requireAdmin, (req, res) => {
  const id = Number(req.params.id);
  DB = readJsonSafe(DB_PATH, DB);
  const before = DB.employees.length;
  DB.employees = DB.employees.filter(e => e.id !== id);
  if (DB.employees.length === before) {
    return res.status(404).json({ ok: false, error: 'NotFound' });
  }
  writeJsonSafe(DB_PATH, DB);
  res.status(200).json({ ok: true });
});

// ====== API – Admin: podsumowanie ======
app.get('/api/admin/summary', authMiddleware, requireAdmin, (req, res) => {
  DB = readJsonSafe(DB_PATH, DB);

  const totalEmployees = DB.employees.length;
  const activeEmployees = DB.employees.filter(e => e.active !== false).length;

  // Zdarzenia z ostatnich 24h
  const now = Date.now();
  const dayAgo = now - 24 * 60 * 60 * 1000;
  const recentEvents = DB.events.filter(ev => {
    const t = new Date(ev.ts).getTime();
    return Number.isFinite(t) && t >= dayAgo;
  }).slice(-100); // ostatnie 100

  res.status(200).json({
    ok: true,
    data: {
      totalEmployees,
      activeEmployees,
      recentEvents
    }
  });
});

// POST /api/clock body: { employeeId: number, type?: 'in'|'out' }
app.post('/api/clock', (req, res) => {
  const { employeeId, type } = req.body || {};
  if (!employeeId) {
    return res.status(400).json({ ok: false, error: 'ValidationError', message: 'Wymagane: employeeId' });
  }

  DB = readJsonSafe(DB_PATH, DB);

  const emp = DB.employees.find(e => e.id === Number(employeeId) && e.active !== false);
  if (!emp) {
    return res.status(404).json({ ok: false, error: 'EmployeeNotFound' });
  }

  let nextType = type;
  if (nextType !== 'in' && nextType !== 'out') {
    const last = [...DB.events].reverse().find(ev => ev.employeeId === emp.id);
    nextType = last && last.type === 'in' ? 'out' : 'in';
  }

  const ev = {
    id: DB.nextEventId++,
    employeeId: emp.id,
    type: nextType,
    ts: new Date().toISOString()
  };
  DB.events.push(ev);
  writeJsonSafe(DB_PATH, DB);

  res.status(201).json({ ok: true, data: { employee: { id: emp.id, name: emp.name }, event: ev } });
});

// === ALIASY /admin/* (bez /api) ===

// summary (alias do /api/admin/summary)
app.get('/admin/summary', authMiddleware, requireAdmin, (req, res) => {
  DB = readJsonSafe(DB_PATH, DB);
  const totalEmployees = DB.employees.length;
  const activeEmployees = DB.employees.filter(e => e.active !== false).length;
  const now = Date.now();
  const dayAgo = now - 24 * 60 * 60 * 1000;
  const recentEvents = DB.events.filter(ev => {
    const t = new Date(ev.ts).getTime();
    return Number.isFinite(t) && t >= dayAgo;
  }).slice(-100);
  res.status(200).json({ ok: true, data: { totalEmployees, activeEmployees, recentEvents } });
});

// employees (alias do /api/admin/employees) — jeśli zakładka czasem uderza bez /api
app.get('/admin/employees', authMiddleware, requireAdmin, (req, res) => {
  DB = readJsonSafe(DB_PATH, DB);
  res.status(200).json({
    ok: true,
    data: DB.employees.map(e => ({
      id: e.id, name: e.name, cardUid: e.cardUid, active: e.active !== false
    }))
  });
});

// events/logs – przydatne dla zakładki „Zdarzenia” lub „Logi”
app.get('/admin/events', authMiddleware, requireAdmin, (req, res) => {
  DB = readJsonSafe(DB_PATH, DB);
  res.status(200).json({ ok: true, data: DB.events.slice(-500) });
});

// settings – prosta odpowiedź, jeśli UI czegoś tam oczekuje
app.get('/admin/settings', authMiddleware, requireAdmin, (req, res) => {
  res.status(200).json({
    ok: true,
    data: {
      version: '1.0',
      clockMode: 'toggle', // in/out automatycznie
    }
  });
});



// ====== 404 JSON tylko dla /api ======
app.use('/api', (req, res) => {
  res.status(404).json({ ok: false, error: 'NotFound', path: req.originalUrl });
});
app.use('/admin', (req, res) => {
  res.status(404).json({ ok: false, error: 'NotFound', path: req.originalUrl });
});


// ====== Globalny handler błędów (JSON) ======
app.use((err, req, res, next) => {
  console.error('API ERROR:', err);
  const status = err?.status || 500;
  res.status(status).json({
    ok: false,
    error: err?.name || 'ServerError',
    message: err?.message || 'Internal error'
  });
});

// ====== (Opcjonalnie) statyczne pliki SPA poza /api ======
// Upewnij się, że NIGDY nie łapią /api/**
// const publicDir = path.join(__dirname, 'public');
// if (fs.existsSync(publicDir)) {
//   app.use(express.static(publicDir));
//   app.get('*', (req, res, next) => {
//     if (req.path.startsWith('/api/')) return next();
//     res.sendFile(path.join(publicDir, 'index.html'));
//   });
// }

// ====== Start ======
app.listen(PORT, () => {
  console.log(`[gateway] listening on http://localhost:${PORT}`);
});
