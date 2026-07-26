#!/usr/bin/env node
/**
 * 发布模拟器 APK 新版本（POST /api/access/v1/emulator-versions）
 *
 * 依赖：Node.js 18+（推荐 20+，大文件上传使用流式读取），无第三方包。
 * 所需令牌作用域：emulator_apk:publish
 *
 * 用法：
 *   # 上传 APK 文件（version_code/version 自动从 APK 读取）
 *   node tool/publish_emulator_apk.js \
 *     --server https://example.com \
 *     --token mrp_at_xxxx \
 *     --file build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
 *     --architecture arm64-v8a \
 *     --changelog "修复若干问题"
 *
 *   # 使用外部下载地址（version_code 必填）
 *   node tool/publish_emulator_apk.js \
 *     --server https://example.com \
 *     --token mrp_at_xxxx \
 *     --download-url https://example.com/emulator-1.2.3.apk \
 *     --version-code 42 --version 1.2.3
 *
 *   # 服务端下载文件（fetch_file，version_code/version/file_size/checksum 自动从文件获取）
 *   node tool/publish_emulator_apk.js \
 *     --server https://example.com \
 *     --token mrp_at_xxxx \
 *     --download-url https://example.com/emulator-1.2.3.apk \
 *     --fetch-file
 *
 * 服务器地址与令牌也可通过环境变量提供：MRP_SERVER / MRP_ACCESS_TOKEN
 */

'use strict';

const fs = require('fs');
const path = require('path');

const ARCHITECTURES = ['universal', 'arm64-v8a', 'armeabi-v7a'];

function usage(exitCode) {
  console.log(`用法: node tool/publish_emulator_apk.js [选项]

选项:
  --server <url>          服务器地址（或环境变量 MRP_SERVER）
  --token <token>         访问令牌 mrp_at_...（或环境变量 MRP_ACCESS_TOKEN）
  --file <path>           APK 文件路径（与 --download-url 二选一）
  --download-url <url>    APK 外部下载地址（与 --file 二选一）
  --architecture <abi>    APK 架构：universal、arm64-v8a、armeabi-v7a
                          （默认 universal）
  --fetch-file            将 download_url 的文件下载到服务器（须为 http(s) 地址），
                          version_code/version/file_size/checksum 自动从文件获取
  --version-code <int>    版本号，使用 --download-url 且未开启 --fetch-file 时必填
  --version <string>      版本名称，例如 1.2.3
  --changelog <text>      更新日志
  --changelog-file <path> 从文件读取更新日志
  --changelog-md <path>   从 CHANGELOG.MD 解析更新日志：提取 "## v<version>" 段落，
                          需配合 --version 使用（以上三者互斥）
  --force-update          强制更新（默认否）
  --checksum <sha256>     文件 SHA-256（仅 --download-url 且未开启 --fetch-file 时有意义，
                          使用 --file 时服务端自动计算）
  --file-size <bytes>     文件大小（仅 --download-url 且未开启 --fetch-file 时有意义）
  -h, --help              显示帮助
`);
  process.exit(exitCode);
}

function parseArgs(argv) {
  const opts = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const next = () => {
      if (i + 1 >= argv.length) fail(`选项 ${arg} 缺少参数值`);
      return argv[++i];
    };
    switch (arg) {
      case '--server': opts.server = next(); break;
      case '--token': opts.token = next(); break;
      case '--file': opts.file = next(); break;
      case '--download-url': opts.downloadUrl = next(); break;
      case '--architecture': opts.architecture = next(); break;
      case '--fetch-file': opts.fetchFile = true; break;
      case '--version-code': opts.versionCode = next(); break;
      case '--version': opts.version = next(); break;
      case '--changelog': opts.changelog = next(); break;
      case '--changelog-file': opts.changelogFile = next(); break;
      case '--changelog-md': opts.changelogMd = next(); break;
      case '--checksum': opts.checksum = next(); break;
      case '--file-size': opts.fileSize = next(); break;
      case '--force-update': opts.forceUpdate = true; break;
      case '-h':
      case '--help': usage(0); break;
      default: fail(`未知选项: ${arg}（使用 --help 查看用法）`);
    }
  }
  return opts;
}

function fail(message) {
  console.error(`错误: ${message}`);
  process.exit(1);
}

// 从 CHANGELOG.MD 中提取指定版本的段落内容。
// 段落以 "## v<version>" 开头（版本号后可跟 " / 日期" 等内容），到下一个 "## " 或文件末尾结束。
function extractChangelog(mdPath, version) {
  const content = fs.readFileSync(mdPath, 'utf8');
  const lines = content.split(/\r?\n/);
  const headingRe = new RegExp(`^##\\s+v?${version.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(\\s|$)`);
  const start = lines.findIndex((line) => headingRe.test(line));
  if (start === -1) fail(`在 ${mdPath} 中未找到版本 ${version} 的更新日志（缺少 "## v${version}" 标题）`);
  let end = lines.length;
  for (let i = start + 1; i < lines.length; i++) {
    if (/^##\s/.test(lines[i])) { end = i; break; }
  }
  const body = lines.slice(start + 1, end).join('\n').trim();
  if (!body) fail(`${mdPath} 中版本 ${version} 的更新日志内容为空`);
  return body;
}

async function fileToBlob(filePath) {
  // Node 20+ 的 openAsBlob 按需流式读取，避免 1GB 级 APK 占满内存
  if (typeof fs.openAsBlob === 'function') {
    return fs.openAsBlob(filePath, { type: 'application/vnd.android.package-archive' });
  }
  const buffer = await fs.promises.readFile(filePath);
  return new Blob([buffer], { type: 'application/vnd.android.package-archive' });
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));

  const server = opts.server || process.env.MRP_SERVER;
  const token = opts.token || process.env.MRP_ACCESS_TOKEN;
  if (!server) fail('缺少服务器地址：请使用 --server 或设置环境变量 MRP_SERVER');
  if (!token) fail('缺少访问令牌：请使用 --token 或设置环境变量 MRP_ACCESS_TOKEN');
  if (!opts.file && !opts.downloadUrl) fail('--file 与 --download-url 必须提供其一');
  if (opts.file && opts.downloadUrl) fail('--file 与 --download-url 不能同时提供');
  if (opts.fetchFile && !opts.downloadUrl) fail('--fetch-file 需要配合 --download-url 使用');
  if (opts.fetchFile && !/^https?:\/\//i.test(opts.downloadUrl)) fail('--fetch-file 时 --download-url 必须为 http(s) 地址');
  if (opts.downloadUrl && !opts.fetchFile && !opts.versionCode) fail('使用 --download-url 且未开启 --fetch-file 时 --version-code 必填');
  if (opts.fetchFile && (opts.checksum || opts.fileSize !== undefined)) {
    fail('--fetch-file 开启后 checksum/file_size 由服务端计算，不能同时提供 --checksum / --file-size');
  }
  opts.architecture = opts.architecture || 'universal';
  if (!ARCHITECTURES.includes(opts.architecture)) {
    fail(`--architecture 必须为以下值之一: ${ARCHITECTURES.join('、')}`);
  }
  const changelogSources = [opts.changelog, opts.changelogFile, opts.changelogMd].filter((v) => v !== undefined);
  if (changelogSources.length > 1) fail('--changelog、--changelog-file、--changelog-md 只能提供其一');
  if (opts.changelogMd && !opts.version) fail('使用 --changelog-md 时 --version 必填');

  if (opts.versionCode !== undefined) {
    const n = Number(opts.versionCode);
    if (!Number.isInteger(n) || n < 0) fail(`--version-code 必须为非负整数: ${opts.versionCode}`);
    opts.versionCode = n;
  }

  let changelog = opts.changelog;
  if (opts.changelogFile) {
    if (!fs.existsSync(opts.changelogFile)) fail(`更新日志文件不存在: ${opts.changelogFile}`);
    changelog = fs.readFileSync(opts.changelogFile, 'utf8').trim();
  } else if (opts.changelogMd) {
    if (!fs.existsSync(opts.changelogMd)) fail(`CHANGELOG 文件不存在: ${opts.changelogMd}`);
    changelog = extractChangelog(opts.changelogMd, opts.version);
    console.log(`从 ${opts.changelogMd} 解析到版本 ${opts.version} 的更新日志:\n${changelog}\n`);
  }

  const url = `${server.replace(/\/+$/, '')}/api/access/v1/emulator-versions`;
  let body;
  const headers = { Authorization: `Bearer ${token}` };

  if (opts.file) {
    const filePath = path.resolve(opts.file);
    if (!fs.existsSync(filePath)) fail(`APK 文件不存在: ${filePath}`);
    const stat = fs.statSync(filePath);
    if (stat.size > 1024 * 1024 * 1024) fail(`文件超过 1GB 限制: ${(stat.size / 1024 / 1024).toFixed(1)} MB`);

    console.log(`上传文件: ${filePath} (${(stat.size / 1024 / 1024).toFixed(2)} MB)`);

    const form = new FormData();
    if (opts.versionCode !== undefined) form.set('version_code', String(opts.versionCode));
    if (opts.version) form.set('version', opts.version);
    form.set('architecture', opts.architecture);
    if (changelog) form.set('changelog', changelog);
    form.set('force_update', opts.forceUpdate ? 'true' : 'false');
    form.set('file', await fileToBlob(filePath), path.basename(filePath));
    body = form;
    // Content-Type 由 fetch 根据 FormData 自动设置（含 boundary）
  } else {
    const payload = {
      download_url: opts.downloadUrl,
      architecture: opts.architecture,
      force_update: !!opts.forceUpdate,
    };
    if (opts.versionCode !== undefined) payload.version_code = opts.versionCode;
    if (opts.fetchFile) payload.fetch_file = true;
    if (opts.version) payload.version = opts.version;
    if (changelog) payload.changelog = changelog;
    if (opts.checksum) payload.checksum = opts.checksum;
    if (opts.fileSize !== undefined) payload.file_size = Number(opts.fileSize);
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(payload);
  }

  console.log(`发布架构: ${opts.architecture}`);
  console.log(`发布到: ${url}`);
  let response;
  try {
    response = await fetch(url, { method: 'POST', headers, body });
  } catch (err) {
    fail(`请求失败: ${err.cause?.message || err.message}`);
  }

  const text = await response.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = null;
  }

  if (response.status === 201) {
    console.log('发布成功:');
    console.log(JSON.stringify(data, null, 2));
    return;
  }

  const reason = data?.error || text || '(无响应内容)';
  const hint = {
    400: '参数错误（version_code 缺失或不大于已有最大版本号、未提供 file/download_url、文件超限、fetch_file 下载失败等）',
    401: '令牌无效、已过期或已撤销',
    403: '令牌缺少 emulator_apk:publish 作用域',
  }[response.status];
  fail(`发布失败 (HTTP ${response.status}${hint ? `，${hint}` : ''}): ${reason}`);
}

main().catch((err) => fail(err.stack || String(err)));
