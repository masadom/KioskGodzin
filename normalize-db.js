// normalize-db.js
const fs = require('fs');
const path = require('path');

const DB_PATH = path.resolve(__dirname, 'db.json');
const db = JSON.parse(fs.readFileSync(DB_PATH, 'utf8'));

function toInt(v) {
  if (typeof v === 'number') return v;
  const n = parseInt(String(v), 10);
  return Number.isFinite(n) ? n : null;
}

function normalizeCollection(name, extraFix) {
  if (!Array.isArray(db[name])) return;
  const arr = db[name];

  // Zamień id na liczby gdy się da
  arr.forEach(it => {
    const n = toInt(it.id);
    if (n !== null) it.id = n;
  });

  // Nadaj brakujące id i zrób je unikalne
  let max = arr
    .map(it => (typeof it.id === 'number' ? it.id : 0))
    .reduce((a, b) => Math.max(a, b), 0);

  arr.forEach(it => {
    if (typeof it.id !== 'number') {
      max += 1;
      it.id = max;
    }
  });

  if (typeof extraFix === 'function') extraFix(arr);
}

normalizeCollection('employees');
normalizeCollection('roles');
normalizeCollection('work_shifts');
normalizeCollection('absences');

normalizeCollection('shifts', (arr) => {
  // employee_id → liczba lub null
  const empIds = new Set((db.employees || []).map(e => e.id));
  arr.forEach(s => {
    const n = toInt(s.employee_id);
    s.employee_id = (n !== null && empIds.has(n)) ? n : null;
  });
});

fs.writeFileSync(DB_PATH, JSON.stringify(db, null, 2));
console.log('✓ Znormalizowano db.json (id → liczby, employee_id poprawione)');
