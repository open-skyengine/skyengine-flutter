#!/usr/bin/env node
/**
 * 使用七牛官方 Node.js SDK 分片上传文件，并输出私有空间下载凭证 URL。
 *
 * 必需环境变量：
 *   QINIU_ACCESS_KEY       七牛 AccessKey
 *   QINIU_SECRET_KEY       七牛 SecretKey
 *   QINIU_BUCKET           对象存储空间名
 *   QINIU_DOMAIN           已绑定私有空间的域名，例如 https://download.example.com
 *
 * 可选环境变量：
 *   QINIU_KEY_PREFIX       对象 key 前缀，默认 releases
 *   QINIU_URL_TTL          下载 URL 有效秒数，默认 3600
 *
 * 用法：
 *   node tool/upload-file-qiniu.js <文件路径>
 *   node tool/upload-file-qiniu.js <文件路径> --key <对象key> --expires 3600
 *   node tool/upload-file-qiniu.js <文件路径> --json
 */

'use strict';

const fs = require('node:fs');
const path = require('node:path');
const qiniu = require('qiniu');

const DEFAULT_KEY_PREFIX = 'releases';
const DEFAULT_URL_TTL = 3600;
const MAX_URL_TTL = 7 * 24 * 60 * 60;

class UsageError extends Error {}

function usage() {
  return `用法: node tool/upload-file-qiniu.js <文件路径> [选项]

选项:
  --key <key>          指定七牛对象 key；默认生成 releases/<时间戳>-<文件名>
  --expires <seconds>  私有下载 URL 有效秒数，默认 3600，最大 604800
  --json               输出包含 key、hash、size、expiresAt 和 downloadUrl 的 JSON
  -h, --help           显示帮助`;
}

function parseArgs(argv) {
  const options = { asJson: false, key: null, expires: null, filePath: null, help: false };
  const positionals = [];
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '-h' || arg === '--help') {
      options.help = true;
    } else if (arg === '--json') {
      options.asJson = true;
    } else if (arg === '--key' || arg === '--expires') {
      const value = argv[index + 1];
      if (value === undefined || value.startsWith('--')) throw new UsageError(`${arg} 缺少参数值`);
      options[arg === '--key' ? 'key' : 'expires'] = value;
      index += 1;
    } else if (arg.startsWith('--key=')) {
      options.key = arg.slice('--key='.length);
    } else if (arg.startsWith('--expires=')) {
      options.expires = arg.slice('--expires='.length);
    } else if (arg.startsWith('-')) {
      throw new UsageError(`未知参数: ${arg}`);
    } else {
      positionals.push(arg);
    }
  }
  if (positionals.length > 1) throw new UsageError(`只能上传一个文件: ${positionals.slice(1).join(', ')}`);
  options.filePath = positionals[0] || null;
  return options;
}

function requiredEnv(env, name) {
  const value = env[name]?.trim();
  if (!value) throw new Error(`缺少环境变量 ${name}`);
  return value;
}

function parseUrlTtl(value) {
  const ttl = value === undefined || value === null || value === '' ? DEFAULT_URL_TTL : Number(value);
  if (!Number.isInteger(ttl) || ttl < 1 || ttl > MAX_URL_TTL) {
    throw new Error(`URL 有效期必须是 1-${MAX_URL_TTL} 之间的整数秒: ${value}`);
  }
  return ttl;
}

function normalizeDomain(value) {
  const withScheme = /^https?:\/\//i.test(value) ? value : `https://${value}`;
  let url;
  try {
    url = new URL(withScheme);
  } catch {
    throw new Error(`QINIU_DOMAIN 不是有效域名: ${value}`);
  }
  if (!['http:', 'https:'].includes(url.protocol) || url.pathname !== '/' || url.search || url.hash) {
    throw new Error(`QINIU_DOMAIN 必须是无路径和参数的 HTTP(S) 域名: ${value}`);
  }
  return url.origin;
}

function validateObjectKey(value) {
  if (!value || value.startsWith('/') || /[\u0000-\u001f\u007f?#\\]/.test(value)) {
    throw new Error(`七牛对象 key 无效: ${JSON.stringify(value)}`);
  }
  return value;
}

function buildObjectKey(fileName, prefix = DEFAULT_KEY_PREFIX, now = Date.now()) {
  const normalizedPrefix = prefix.trim().replace(/^\/+|\/+$/g, '');
  const key = normalizedPrefix ? `${normalizedPrefix}/${now}-${fileName}` : `${now}-${fileName}`;
  return validateObjectKey(key);
}

function createPrivateDownloadUrl(domain, objectKey, accessKey, secretKey, deadline) {
  const mac = new qiniu.auth.digest.Mac(accessKey, secretKey);
  const bucketManager = new qiniu.rs.BucketManager(mac, new qiniu.conf.Config());
  return bucketManager.privateDownloadUrl(
    normalizeDomain(domain),
    validateObjectKey(objectKey),
    deadline,
  );
}

function loadConfig(env, options) {
  const expires = parseUrlTtl(options.expires ?? env.QINIU_URL_TTL);
  return {
    accessKey: requiredEnv(env, 'QINIU_ACCESS_KEY'),
    secretKey: requiredEnv(env, 'QINIU_SECRET_KEY'),
    bucket: requiredEnv(env, 'QINIU_BUCKET'),
    domain: normalizeDomain(requiredEnv(env, 'QINIU_DOMAIN')),
    keyPrefix: env.QINIU_KEY_PREFIX?.trim() || DEFAULT_KEY_PREFIX,
    expires,
  };
}

function describeSdkError(error) {
  const status = error?.resp?.statusCode || error?.response?.statusCode;
  const detail = error?.data?.error || error?.message || String(error);
  return `${status ? `HTTP ${status}: ` : ''}${detail}`;
}

function createUploadToken(config, objectKey) {
  const mac = new qiniu.auth.digest.Mac(config.accessKey, config.secretKey);
  const putPolicy = new qiniu.rs.PutPolicy({
    scope: `${config.bucket}:${objectKey}`,
    insertOnly: 1,
    expires: 3600,
  });
  return putPolicy.uploadToken(mac);
}

async function uploadFile(filePath, objectKey, config) {
  const uploadToken = createUploadToken(config, objectKey);
  const sdkConfig = new qiniu.conf.Config();
  sdkConfig.useHttpsDomain = true;
  sdkConfig.useCdnDomain = true;
  const uploader = new qiniu.resume_up.ResumeUploader(sdkConfig);
  const putExtra = qiniu.resume_up.PutExtra.create();
  putExtra.fname = path.basename(filePath);
  putExtra.mimeType = path.extname(filePath).toLowerCase() === '.apk'
    ? 'application/vnd.android.package-archive'
    : null;
  let lastProgress = -1;
  putExtra.progressCallback = (uploadedBytes, totalBytes) => {
    const progress = totalBytes > 0 ? Math.min(100, Math.floor((uploadedBytes / totalBytes) * 100)) : 100;
    if (progress !== lastProgress) {
      console.error(`上传进度: ${progress}%`);
      lastProgress = progress;
    }
  };

  const { data, resp } = await uploader.putFileV2(uploadToken, objectKey, filePath, putExtra);
  if (resp.statusCode !== 200) {
    throw new Error(`上传失败 (HTTP ${resp.statusCode}): ${data?.error || JSON.stringify(data)}`);
  }
  if (!data?.key || data.key !== objectKey) {
    throw new Error(`上传结果缺少预期对象 key: ${data?.key || '(空)'}`);
  }
  return data;
}

async function main() {
  let options;
  try {
    options = parseArgs(process.argv.slice(2));
  } catch (error) {
    if (error instanceof UsageError) {
      console.error(`错误: ${error.message}\n\n${usage()}`);
      process.exitCode = 1;
      return;
    }
    throw error;
  }
  if (options.help) {
    console.log(usage());
    return;
  }
  if (!options.filePath) throw new UsageError(`缺少文件路径\n\n${usage()}`);

  const config = loadConfig(process.env, options);
  const absolutePath = path.resolve(options.filePath);
  const stat = await fs.promises.stat(absolutePath).catch((error) => {
    if (error.code === 'ENOENT') throw new Error(`文件不存在: ${absolutePath}`);
    throw error;
  });
  if (!stat.isFile()) throw new Error(`不是文件: ${absolutePath}`);

  const fileName = path.basename(absolutePath);
  const objectKey = options.key
    ? validateObjectKey(options.key)
    : buildObjectKey(fileName, config.keyPrefix);
  console.error(`上传文件: ${fileName} (${(stat.size / 1024 / 1024).toFixed(2)} MB)`);
  console.error(`七牛对象 key: ${objectKey}`);

  let uploadResult;
  try {
    uploadResult = await uploadFile(absolutePath, objectKey, config);
  } catch (error) {
    throw new Error(`七牛上传失败: ${describeSdkError(error)}`);
  }

  const deadline = Math.floor(Date.now() / 1000) + config.expires;
  const result = {
    key: objectKey,
    hash: uploadResult.hash || null,
    size: stat.size,
    expiresAt: new Date(deadline * 1000).toISOString(),
    downloadUrl: createPrivateDownloadUrl(
      config.domain,
      objectKey,
      config.accessKey,
      config.secretKey,
      deadline,
    ),
  };
  console.error('上传成功，私有空间下载凭证 URL:');
  console.log(options.asJson ? JSON.stringify(result, null, 2) : result.downloadUrl);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`错误: ${error.message || String(error)}`);
    process.exit(1);
  });
}

module.exports = {
  UsageError,
  buildObjectKey,
  createPrivateDownloadUrl,
  createUploadToken,
  loadConfig,
  normalizeDomain,
  parseArgs,
  parseUrlTtl,
  validateObjectKey,
};
