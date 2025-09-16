// server.js
const jsonServer = require('json-server');
const path = require('path');
const fs = require('fs');

const DB_PATH = path.resolve(__dirname, 'db.json');
const server = jsonServer.create();
const router = jsonServer.router(DB_PATH);
const middlewares = jsonServer.defaults();

server.use(middlewares);
server.use(jsonServer.bodyParser);

// Funkcja do wyznaczania kolejnego numerycznego ID
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

// Middleware wymuszający numeryczne ID na POST
server.post('/:collection', (req, res, next) => {
  const { collection } = req.params;
  const supported = ['employees', 'shifts', 'roles', 'work_shifts', 'absences'];

  if (supported.includes(collection)) {
    req.body = req.body || {};
    req.body.id = nextNumericId(collection);

    if (collection === 'shifts' && req.body.employee_id != null) {
      const n = parseInt(String(req.body.employee_id), 10);
      req.body.employee_id = Number.isFinite(n) ? n : null;
    }
  }
  next();
});

server.use(router);

const PORT = 3000;
server.listen(PORT, () => {
  console.log(`✓ JSON Server with numeric IDs running at http://localhost:${PORT}`);
});
