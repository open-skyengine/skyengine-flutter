#!/usr/bin/env node
/**
 * 通过 sodatool.com 文件快传上传文件，输出最终下载链接。
 *
 * 上传流程（从 https://www.sodatool.com/tool/file-transfer 页面逻辑还原）：
 *   1. GET  https://www.sodatool.com/api/tools/files/upload-token
 *        -> { success, token, domain, remainingUploads }（七牛云上传凭证）
 *   2. POST https://upload.qiniup.com  (multipart/form-data)
 *        字段: file, token, key = `${Date.now()}_${文件名}`, x:name = 文件名
 *        -> { key, hash, fsize, bucket, name }
 *   3. POST https://www.sodatool.com/api/tools/files  (application/json)
 *        body: { filePath: key, fileName, fileHash }
 *        -> { uuid, downloadUrl: "https://sodatool.com/d/<uuid>", expiresAt }
 *   4.（--direct）GET https://www.sodatool.com/api/tools/files/<uuid>
 *        -> { downloadUrl: 签名后的 CDN 直链, fileName }（直链短时效，约 2 分钟）
 *
 * 限制：单文件最大 500MB；文件约 7 天过期，下载次数有限制，仅适合临时分发。
 *
 * 依赖：Node.js 18+（推荐 20+，使用流式读取上传大文件）。
 *
 * 用法：
 *   node tool/upload-file.js <文件路径>            # 输出分享页链接 /d/<uuid>
 *   node tool/upload-file.js <文件路径> --direct   # 额外获取签名 CDN 直链（短时效）
 *   node tool/upload-file.js <文件路径> --json     # 输出完整 JSON 结果
 *
 * 成功时最后一行输出下载链接（--json 时输出 JSON）。
 */

'use strict';

const fs = require('fs');
const path = require('path');

const API_BASE = 'https://www.sodatool.com';
const UPLOAD_URL = 'https://upload.qiniup.com';
const MAX_SIZE = 524288000; // 500MB，与页面 token 中的 fsizeLimit 一致

const COMMON_HEADERS = {
  Origin: 'https://www.sodatool.com',
  Referer: 'https://www.sodatool.com/tool/file-transfer',
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) upload-file.js',
};

function fail(message) {
  console.error(`错误: ${message}`);
  process.exit(1);
}

async function fileToBlob(filePath) {
  if (typeof fs.openAsBlob === 'function') {
    return fs.openAsBlob(filePath);
  }
  return new Blob([await fs.promises.readFile(filePath)]);
}

async function fetchJson(url, options, step) {
  let response;
  try {
    response = await fetch(url, options);
  } catch (err) {
    fail(`${step}请求失败: ${err.cause?.message || err.message}`);
  }
  const text = await response.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    fail(`${step}返回非 JSON (HTTP ${response.status}): ${text.slice(0, 300)}`);
  }
  if (!response.ok) {
    fail(`${step}失败 (HTTP ${response.status}): ${data.error || data.message || text.slice(0, 300)}`);
  }
  return data;
}

async function main() {
  const args = process.argv.slice(2);
  const asJson = args.includes('--json');
  const wantDirect = args.includes('--direct');
  const filePath = args.find((a) => !a.startsWith('--'));
  if (!filePath) {
    console.log('用法: node tool/upload-file.js <文件路径> [--direct] [--json]');
    process.exit(args.includes('-h') || args.includes('--help') ? 0 : 1);
  }

  const absPath = path.resolve(filePath);
  if (!fs.existsSync(absPath)) fail(`文件不存在: ${absPath}`);
  const stat = fs.statSync(absPath);
  if (!stat.isFile()) fail(`不是文件: ${absPath}`);
  if (stat.size > MAX_SIZE) fail(`文件超过 500MB 限制: ${(stat.size / 1024 / 1024).toFixed(1)} MB`);

  const fileName = path.basename(absPath);
  console.error(`上传文件: ${fileName} (${(stat.size / 1024 / 1024).toFixed(2)} MB)`);

  // 1. 获取上传凭证
  const tokenRes = await fetchJson(
    `${API_BASE}/api/tools/files/upload-token`,
    { headers: COMMON_HEADERS },
    '获取上传凭证',
  );
  if (!tokenRes.success || !tokenRes.token) {
    const code = tokenRes.message || tokenRes.code;
    if (code === 'UPLOAD_DAILY_LIMIT') fail('获取上传凭证失败: 当日上传次数已用完（按 IP 限制，次日重置）');
    fail(`获取上传凭证失败: ${code || JSON.stringify(tokenRes).slice(0, 300)}`);
  }
  if (tokenRes.remainingUploads !== undefined) {
    console.error(`剩余上传次数: ${tokenRes.remainingUploads}`);
  }

  // 2. 上传到七牛云
  const key = `${Date.now()}_${fileName}`;
  const form = new FormData();
  form.append('file', await fileToBlob(absPath), fileName);
  form.append('token', tokenRes.token);
  form.append('key', key);
  form.append('x:name', fileName);

  console.error('上传中...');
  const uploadRes = await fetchJson(
    UPLOAD_URL,
    { method: 'POST', body: form, headers: COMMON_HEADERS },
    '上传文件',
  );

  // 3. 登记文件，换取下载链接
  const record = await fetchJson(
    `${API_BASE}/api/tools/files`,
    {
      method: 'POST',
      headers: { ...COMMON_HEADERS, 'Content-Type': 'application/json' },
      body: JSON.stringify({ filePath: key, fileName, fileHash: uploadRes.hash || null }),
    },
    '登记文件',
  );

  if (!record.downloadUrl) {
    fail(`服务端未返回下载链接: ${JSON.stringify(record).slice(0, 300)}`);
  }

  // 4.（可选）用 uuid 换取签名后的 CDN 直链（curl/wget 可直接下载，但签名短时效）
  if (wantDirect && record.uuid) {
    const direct = await fetchJson(
      `${API_BASE}/api/tools/files/${record.uuid}`,
      { headers: COMMON_HEADERS },
      '获取直链',
    );
    record.directUrl = direct.downloadUrl;
  }

  console.error('上传成功，下载链接:');
  console.log(asJson ? JSON.stringify(record, null, 2) : record.directUrl || record.downloadUrl);
}

main().catch((err) => fail(err.stack || String(err)));
