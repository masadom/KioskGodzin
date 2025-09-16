// force-numeric-ids.js
const fs = require('fs');
const path = require('path');

const DB_PATH = path.resolve(__dirname, 'db.json');

function nextNumericId(collName) {
  const db = JSON.parse(fs.readFileSync(DB_PATH, 'utf8'));
  const arr = db[collName] || [];
  const nums = arr
    .map(it => {
      const n = parseInt(String(it.id), 10);
      return Number.isFinite(n) ? n : null;
    })
    .filter(n => n !== null);
  return nums.length ? Math.max(...nums) + 1 : 1;
}

module.exports = (req, res, next) => {
  // Reaguj tylko na POST-y do wspieranych kolekcji
  if (req.method === 'POST') {
    const m = req.path.match(/^\/(employees|shifts|roles|work_shifts|absences)$/);
    if (m) {
      const coll = m[1];
      req.body = req.body || {};
      req.body.id = nextNumericId(coll);
      if (coll === 'shifts' && req.body.employee_id != null) {
        const n = parseInt(String(req.body.employee_id), 10);
        req.body.employee_id = Number.isFinite(n) ? n : null;
      }
    }
  }
  next();
};
