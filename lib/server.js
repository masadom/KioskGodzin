// server.js
const jsonServer = require('json-server');
const path = require('path');
const server = jsonServer.create();
const router = jsonServer.router(path.join(__dirname, 'db.json'));
const middlewares = jsonServer.defaults();

server.use(middlewares);
server.use(jsonServer.bodyParser);

// Unikalność PIN w /employees dla POST/PUT/PATCH
server.use((req, res, next) => {
  const mut = ['POST', 'PUT', 'PATCH'].includes(req.method);
  if (!mut || !req.path.startsWith('/employees')) return next();

  const db = router.db; // lowdb
  const body = req.body || {};
  if (body.pin == null) return next();

  const pinStr = String(body.pin);
  const idParam = req.params?.id != null ? Number(req.params.id) : null;

  const conflict = db
    .get('employees')
    .find(e => String(e.pin) === pinStr && (idParam == null || Number(e.id) !== idParam))
    .value();

  if (conflict) {
    return res.status(409).json({
      error: 'PIN_NOT_UNIQUE',
      message: 'PIN must be unique across employees.',
      pin: body.pin
    });
  }
  next();
});

server.use(router);
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log('JSON Server (PIN uniqueness) on', PORT));
