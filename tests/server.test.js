const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const request = require('node:http');

const app = require('../src/server');

function get(path) {
  return new Promise((resolve, reject) => {
    const server = app.listen(0, () => {
      const { port } = server.address();
      request.get(`http://127.0.0.1:${port}${path}`, (res) => {
        let body = '';
        res.on('data', (chunk) => { body += chunk; });
        res.on('end', () => {
          server.close();
          resolve({ status: res.statusCode, body: JSON.parse(body) });
        });
      }).on('error', (err) => {
        server.close();
        reject(err);
      });
    });
  });
}

describe('API endpoints', () => {
  it('returns healthy status', async () => {
    const { status, body } = await get('/health');
    assert.equal(status, 200);
    assert.equal(body.status, 'healthy');
  });

  it('returns app info', async () => {
    const { status, body } = await get('/api/info');
    assert.equal(status, 200);
    assert.equal(body.name, 'DevOps Demo');
  });
});
