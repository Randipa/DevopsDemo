const express = require('express');
const client = require('prom-client');

const app = express();
const metricsRegister = new client.Registry();
client.collectDefaultMetrics({ register: metricsRegister });

const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [metricsRegister]
});
const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const ENVIRONMENT = process.env.NODE_ENV || 'development';
const DEPLOY_ENV = process.env.DEPLOY_ENV || ENVIRONMENT;

app.use(express.json());

app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequestCounter.inc({
      method: req.method,
      route: req.route?.path || req.path,
      status: String(res.statusCode)
    });
  });
  next();
});

app.get('/health', (_req, res) => {
  res.status(200).json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    environment: ENVIRONMENT,
    deployEnv: DEPLOY_ENV,
    version: APP_VERSION
  });
});

app.get('/api/info', (_req, res) => {
  res.json({
    name: 'DevOps Demo',
    version: APP_VERSION,
    environment: ENVIRONMENT,
    deployEnv: DEPLOY_ENV,
    nodeVersion: process.version
  });
});

app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', metricsRegister.contentType);
  res.end(await metricsRegister.metrics());
});

app.get('/api/echo', (req, res) => {
  res.json({
    message: req.query.message || 'Hello from DevOps demo!',
    receivedAt: new Date().toISOString()
  });
});

app.get('/api/name', (req, res) => {
  res.json({
    name: req.query.name || 'DevOps demo'
  });
});

app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

if (require.main === module) {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT} (${ENVIRONMENT})`);
  });
}

module.exports = app;
