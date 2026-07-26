#!/usr/bin/env node
/**
 * 通过 jisuchuan.com 上传文件，输出最终下载链接。
 *
 * 上传流程（通过 Edge DevTools Protocol 从 https://jisuchuan.com/ 还原）：
 *   1. POST https://jisuchuan.com/api/data/getUploadLink/
 *        body: file_name=<文件名>
 *        -> { upload_url: Cloudflare R2 预签名 PUT 地址, file_key }
 *   2. PUT upload_url，body 为原始文件内容
 *   3. POST https://jisuchuan.com/api/data/upload/
 *        body: { file_name, file_size, file_key }
 *        -> { file_id }
 *   4. POST https://jisuchuan.com/api/data/share/
 *        body: { files: file_id, name: 自定义后缀, pwd: 访问密码 }
 *        -> { sid, name, expire_time, ... }
 *   5.（--direct）GET https://jisuchuan.com/api/data/download?key=...&name=...
 *        -> 302 到签名后的 R2 下载地址
 *
 * 限制：单文件最大 200MB；分享和文件约 10 分钟后过期，仅适合临时分发。
 *
 * 依赖：Node.js 18+（推荐 20+，Node.js 18 回退实现会将文件读入内存）。
 *
 * 用法：
 *   node tool/upload-file-jisuchuan.js <文件路径>
 *   node tool/upload-file-jisuchuan.js <文件路径> --direct
 *   node tool/upload-file-jisuchuan.js <文件路径> --json
 *   node tool/upload-file-jisuchuan.js <文件路径> --name <链接后缀> --password <访问密码>
 *
 * 成功时最后输出下载链接（--json 时输出完整 JSON）。
 */

'use strict';

const fs = require('fs');
const path = require('path');

const API_BASE = 'https://jisuchuan.com';
const MAX_SIZE = 200 * 1024 * 1024;

const COMMON_HEADERS = {
  Accept: 'application/json, text/javascript, */*; q=0.01',
  Origin: API_BASE,
  Referer: `${API_BASE}/`,
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) upload-file-jisuchuan.js',
  'X-Requested-With': 'XMLHttpRequest',
};

function fail(message) {
  console.error(`错误: ${message}`);
  process.exit(1);
}

function usage(exitCode) {
  console.log(
    '用法: node tool/upload-file-jisuchuan.js <文件路径> ' +
      '[--direct] [--json] [--name <链接后缀>] [--password <访问密码>]',
  );
  process.exit(exitCode);
}

function parseArgs(args) {
  const options = { asJson: false, direct: false, name: '', password: '', filePath: null };
  const positionals = [];

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === '-h' || arg === '--help') usage(0);
    if (arg === '--json') {
      options.asJson = true;
      continue;
    }
    if (arg === '--direct') {
      options.direct = true;
      continue;
    }
    if (arg === '--name' || arg === '--password') {
      const value = args[index + 1];
      if (value === undefined || value.startsWith('--')) fail(`${arg} 缺少参数值`);
      options[arg === '--name' ? 'name' : 'password'] = value;
      index += 1;
      continue;
    }
    if (arg.startsWith('--name=')) {
      options.name = arg.slice('--name='.length);
      continue;
    }
    if (arg.startsWith('--password=')) {
      options.password = arg.slice('--password='.length);
      continue;
    }
    if (arg.startsWith('-')) fail(`未知参数: ${arg}`);
    positionals.push(arg);
  }

  if (positionals.length > 1) fail(`只能上传一个文件: ${positionals.slice(1).join(', ')}`);
  options.filePath = positionals[0] || null;
  return options;
}

async function fileToBlob(filePath) {
  if (typeof fs.openAsBlob === 'function') {
    return fs.openAsBlob(filePath);
  }
  return new Blob([await fs.promises.readFile(filePath)]);
}

function apiError(data, fallback) {
  return data?.error || data?.msg || data?.message || fallback;
}

async function fetchApi(endpoint, fields, step) {
  let response;
  try {
    response = await fetch(`${API_BASE}${endpoint}`, {
      method: fields ? 'POST' : 'GET',
      headers: fields
        ? { ...COMMON_HEADERS, 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' }
        : COMMON_HEADERS,
      body: fields ? new URLSearchParams(fields) : undefined,
    });
  } catch (err) {
    fail(`${step}请求失败: ${err.cause?.message || err.message}`);
  }

  const text = await response.text();
  let result;
  try {
    result = JSON.parse(text);
  } catch {
    fail(`${step}返回非 JSON (HTTP ${response.status}): ${text.slice(0, 300)}`);
  }
  if (!response.ok) {
    fail(`${step}失败 (HTTP ${response.status}): ${apiError(result, text.slice(0, 300))}`);
  }
  if (result.status !== 1 || !result.data) {
    fail(`${step}失败: ${apiError(result, JSON.stringify(result).slice(0, 300))}`);
  }
  return result.data;
}

async function uploadToR2(uploadUrl, filePath, step) {
  let response;
  try {
    response = await fetch(uploadUrl, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/octet-stream' },
      body: await fileToBlob(filePath),
    });
  } catch (err) {
    fail(`${step}请求失败: ${err.cause?.message || err.message}`);
  }
  if (!response.ok) {
    const text = await response.text();
    fail(`${step}失败 (HTTP ${response.status}): ${text.slice(0, 300)}`);
  }
}

async function getDirectUrl(fileKey, fileName) {
  const url = new URL('/api/data/download', API_BASE);
  url.searchParams.set('key', fileKey);
  url.searchParams.set('name', fileName);

  let response;
  try {
    response = await fetch(url, { headers: COMMON_HEADERS, redirect: 'manual' });
  } catch (err) {
    fail(`获取直链请求失败: ${err.cause?.message || err.message}`);
  }
  if (response.status < 300 || response.status >= 400) {
    const text = await response.text();
    fail(`获取直链失败 (HTTP ${response.status}): ${text.slice(0, 300)}`);
  }
  const location = response.headers.get('location');
  if (!location) fail('获取直链失败: 服务端未返回重定向地址');
  return new URL(location, url).href;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (!options.filePath) usage(1);
  if (options.name && !/^[a-zA-Z0-9_-]+$/.test(options.name)) {
    fail('链接后缀仅支持字母、数字、连字符和下划线');
  }

  const absPath = path.resolve(options.filePath);
  if (!fs.existsSync(absPath)) fail(`文件不存在: ${absPath}`);
  const stat = fs.statSync(absPath);
  if (!stat.isFile()) fail(`不是文件: ${absPath}`);
  if (stat.size > MAX_SIZE) {
    fail(`文件超过 200MB 限制: ${(stat.size / 1024 / 1024).toFixed(1)} MB`);
  }

  const fileName = path.basename(absPath);
  console.error(`上传文件: ${fileName} (${(stat.size / 1024 / 1024).toFixed(2)} MB)`);

  const uploadLink = await fetchApi(
    '/api/data/getUploadLink/',
    { file_name: fileName },
    '获取上传链接',
  );
  if (!uploadLink.upload_url || !uploadLink.file_key) {
    fail(`获取上传链接失败: 响应缺少 upload_url 或 file_key`);
  }

  console.error('上传中...');
  await uploadToR2(uploadLink.upload_url, absPath, '上传文件');

  const fileRecord = await fetchApi(
    '/api/data/upload/',
    {
      file_name: fileName,
      file_size: String(stat.size),
      file_key: uploadLink.file_key,
    },
    '登记文件',
  );
  if (!fileRecord.file_id) fail('登记文件失败: 响应缺少 file_id');

  const share = await fetchApi(
    '/api/data/share/',
    { files: fileRecord.file_id, name: options.name, pwd: options.password },
    '生成分享链接',
  );
  if (!share.name || !share.sid) fail('生成分享链接失败: 响应缺少 name 或 sid');

  const result = {
    ...share,
    downloadUrl: `${API_BASE}/${share.name}`,
    file: {
      fileId: fileRecord.file_id,
      fileKey: uploadLink.file_key,
      fileName,
      fileSize: stat.size,
    },
  };

  if (options.direct) {
    result.directUrl = await getDirectUrl(uploadLink.file_key, fileName);
  }

  console.error('上传成功，下载链接:');
  console.log(options.asJson ? JSON.stringify(result, null, 2) : result.directUrl || result.downloadUrl);
}

main().catch((err) => fail(err.stack || String(err)));
