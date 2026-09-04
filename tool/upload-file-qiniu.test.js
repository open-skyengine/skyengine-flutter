'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const test = require('node:test');
const {
  buildObjectKey,
  createPrivateDownloadUrl,
  createUploadToken,
  loadConfig,
  normalizeDomain,
  parseArgs,
  parseUrlTtl,
  validateObjectKey,
} = require('./upload-file-qiniu');

test('parses upload options', () => {
  assert.deepEqual(parseArgs(['app.apk', '--key', 'release/app.apk', '--expires=120', '--json']), {
    asJson: true,
    key: 'release/app.apk',
    expires: '120',
    filePath: 'app.apk',
    help: false,
  });
});

test('builds a collision-resistant object key', () => {
  assert.equal(
    buildObjectKey('skyengine-v1.apk', '/releases/', 1700000000000),
    'releases/1700000000000-skyengine-v1.apk',
  );
  assert.throws(() => validateObjectKey('../bad?key'), /对象 key 无效/);
});

test('normalizes the CDN domain and validates URL TTL', () => {
  assert.equal(normalizeDomain('download.example.com/'), 'https://download.example.com');
  assert.equal(parseUrlTtl(undefined), 3600);
  assert.throws(() => parseUrlTtl('0'), /1-604800/);
  assert.throws(() => normalizeDomain('https://example.com/path'), /无路径和参数/);
});

test('requires all Qiniu settings', () => {
  const env = {
    QINIU_ACCESS_KEY: 'access',
    QINIU_SECRET_KEY: 'secret',
    QINIU_BUCKET: 'bucket',
    QINIU_DOMAIN: 'cdn.example.com',
  };
  assert.equal(loadConfig(env, {}).expires, 3600);
  assert.throws(() => loadConfig({ ...env, QINIU_BUCKET: '' }, {}), /QINIU_BUCKET/);
});

test('binds the upload token to the exact bucket and object key', () => {
  const token = createUploadToken(
    { accessKey: 'test-access-key', secretKey: 'test-secret-key', bucket: 'private-bucket' },
    'releases/app.apk',
  );
  const policy = JSON.parse(Buffer.from(token.split(':')[2], 'base64url').toString());

  assert.equal(policy.scope, 'private-bucket:releases/app.apk');
  assert.equal(policy.insertOnly, 1);
  assert.ok(policy.deadline > Math.floor(Date.now() / 1000));
});

test('uses the official SDK private download token', () => {
  const deadline = 1700000000;
  const objectKey = 'releases/skyengine v1.apk';
  const signedUrl = new URL(
    createPrivateDownloadUrl(
      'https://cdn.example.com',
      objectKey,
      'test-access-key',
      'test-secret-key',
      deadline,
    ),
  );
  const urlToSign = `https://cdn.example.com${signedUrl.pathname}?e=${deadline}`;
  const encodedSign = crypto
    .createHmac('sha1', 'test-secret-key')
    .update(urlToSign)
    .digest('base64')
    .replace(/\//g, '_')
    .replace(/\+/g, '-');

  assert.equal(signedUrl.pathname, '/releases/skyengine%20v1.apk');
  assert.equal(signedUrl.searchParams.get('e'), String(deadline));
  assert.equal(signedUrl.searchParams.get('token'), `test-access-key:${encodedSign}`);
  assert.match(signedUrl.href, /\?e=1700000000&token=[^&]+$/);
});
