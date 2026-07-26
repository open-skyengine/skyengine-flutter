# APP 端 HTTP API 对接文档

本文档描述 APP 端使用的 HTTP 接口。接口统一使用 HMAC-SHA256 签名验证，只返回可对终端开放的 active 应用、active 厂商、published 版本和 active 分辨率包。

## 1. 基础信息

| 项目 | 说明 |
|------|------|
| Base URL | `http(s)://{host}/api/app/v1` |
| 数据格式 | JSON；下载接口返回二进制文件 |
| 字符编码 | UTF-8 |
| 时间格式 | RFC3339，例如 `2026-06-14T08:00:00Z` |
| 分页参数 | `page`、`page_size` |
| 默认分页 | `page=1&page_size=20` |
| 最大分页 | `page_size=100` |

分页响应统一格式：

```json
{
  "items": [],
  "total": 0,
  "page": 1,
  "page_size": 20
}
```

错误响应统一格式：

```json
{
  "error": "invalid signature"
}
```

## 2. 签名规则

所有 APP 端接口都必须携带签名请求头。

### 2.1 请求头

| Header | 必填 | 说明 |
|--------|------|------|
| `X-App-Key` | 是 | APP 接入 Key，对应服务端 `app_api.key` |
| `X-App-Timestamp` | 是 | Unix 秒或 RFC3339 时间 |
| `X-App-Nonce` | 是 | 随机字符串，建议每次请求不同 |
| `X-App-Signature` | 是 | HMAC-SHA256 签名十六进制字符串 |

服务端默认允许请求时间与服务器时间相差 300 秒，可通过 `app_api.signature_ttl_seconds` 配置。

### 2.2 签名串

签名算法：

```text
hex(HMAC-SHA256(app_api.secret, message))
```

`message` 由 6 行拼接而成，行之间使用换行符 `\n`：

```text
METHOD
PATH
CANONICAL_QUERY
TIMESTAMP
NONCE
BODY_SHA256_HEX
```

字段说明：

| 字段 | 说明 |
|------|------|
| `METHOD` | 大写 HTTP 方法，例如 `GET` |
| `PATH` | URL path，不包含域名和 query，例如 `/api/app/v1/apps` |
| `CANONICAL_QUERY` | 标准化 query 字符串 |
| `TIMESTAMP` | 与 `X-App-Timestamp` 完全一致 |
| `NONCE` | 与 `X-App-Nonce` 完全一致 |
| `BODY_SHA256_HEX` | 请求 body 的 SHA256 十六进制值；GET 空 body 也要计算空字节 SHA256 |

`CANONICAL_QUERY` 规则：

- 使用 URL query 参数。
- 按 key 升序排序。
- 同名参数的 value 按升序排序。
- 使用标准 URL 编码。
- 忽略名为 `signature` 的 query 参数。
- 没有 query 时为空字符串。

空 body 的 SHA256：

```text
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

### 2.3 签名示例

请求：

```http
GET /api/app/v1/apps?page=1&page_size=20 HTTP/1.1
Host: example.com
X-App-Key: dev-app-key
X-App-Timestamp: 1718352000
X-App-Nonce: nonce-001
```

签名串：

```text
GET
/api/app/v1/apps
page=1&page_size=20
1718352000
nonce-001
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

JavaScript 示例：

```js
import crypto from 'node:crypto';

function sign({ method, path, query = '', timestamp, nonce, body = '', secret }) {
  const bodyHash = crypto.createHash('sha256').update(body).digest('hex');
  const message = [
    method.toUpperCase(),
    path,
    query,
    String(timestamp),
    nonce,
    bodyHash,
  ].join('\n');
  return crypto.createHmac('sha256', secret).update(message).digest('hex');
}
```

## 3. 公共查询参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `page` | int | 否 | 页码，默认 `1` |
| `page_size` | int | 否 | 每页数量，默认 `20`，最大 `100` |
| `resolution` | string | 否 | 屏幕分辨率，例如 `240x320` |

## 4. 接口列表

### 4.1 分页获取应用列表

```http
GET /api/app/v1/apps
```

返回 active 厂商下的 active 应用。该接口固定只返回 `app` 类型，并且应用至少有一个 published 版本和 active 分辨率包。

请求参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `page` | int | 否 | 页码 |
| `page_size` | int | 否 | 每页数量 |
| `resolution` | string | 否 | 只返回支持该分辨率的应用 |

响应示例：

```json
{
  "items": [
    {
      "id": 1,
      "app_id": 399484,
      "type": "app",
      "internal_name": "demo",
      "name": "Demo App",
      "manufacturer": {
        "id": 2,
        "name": "Demo Vendor"
      },
      "description": "Demo description",
      "icon_url": "/storage/icons/demo.png",
      "created_at": "2026-06-14T08:00:00Z",
      "updated_at": "2026-06-14T08:00:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "page_size": 20
}
```

### 4.2 分页搜索应用

```http
GET /api/app/v1/apps/search
```

按应用名称、内部名称、描述、厂商名称搜索。`q` 不能为空。

请求参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `q` | string | 是 | 搜索关键词 |
| `page` | int | 否 | 页码 |
| `page_size` | int | 否 | 每页数量 |
| `resolution` | string | 否 | 只搜索支持该分辨率的应用 |

响应格式同应用列表。

`q` 为空时返回：

```json
{
  "error": "q is required"
}
```

### 4.3 查询应用版本列表

```http
GET /api/app/v1/apps/{app_id}/versions
```

`app_id` 为 MRP 应用外部 ID，不是数据库主键。只返回 published 版本。

请求参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `app_id` | uint32 | 是 | 路径参数，MRP 应用外部 ID |
| `page` | int | 否 | 页码 |
| `page_size` | int | 否 | 每页数量 |
| `resolution` | string | 否 | 只返回包含该分辨率包的版本 |

响应示例：

```json
{
  "items": [
    {
      "id": 10,
      "app_id": 399484,
      "version_code": 1002,
      "version": "1.0.2",
      "changelog": "修复已知问题",
      "published_at": "2026-06-14T08:00:00Z",
      "packages": [
        {
          "id": 21,
          "resolution": {
            "id": 3,
            "resolution": "240x320"
          },
          "file_size": 123456,
          "checksum": "sha256-or-md5",
          "download_url": "/api/app/v1/apps/399484/versions/1002/download?resolution=240x320"
        }
      ],
      "created_at": "2026-06-14T08:00:00Z",
      "updated_at": "2026-06-14T08:00:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "page_size": 20
}
```

### 4.4 下载指定版本应用

```http
GET /api/app/v1/apps/{app_id}/versions/{version_code}/download
```

下载指定 `app_id` 和 `version_code` 的 MRP 包。下载接口同样需要签名。

请求参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `app_id` | uint32 | 是 | 路径参数，MRP 应用外部 ID |
| `version_code` | uint32 | 是 | 路径参数，版本号 |
| `resolution` | string | 否 | 指定分辨率包 |

响应：

| 项目 | 说明 |
|------|------|
| HTTP 状态 | `200 OK` |
| Content-Type | `application/octet-stream` |
| Content-Disposition | `attachment; filename="xxx.mrp"` |
| Body | MRP 文件二进制内容 |

响应头：

| Header | 说明 |
|--------|------|
| `X-App-ID` | 应用外部 ID |
| `X-Version-Code` | 版本号 |

没有匹配包时返回：

```json
{
  "error": "download package not found"
}
```

### 4.5 检测安卓模拟器更新

```http
GET /api/app/v1/emulator/updates
```

查询当前已发布的最新安卓模拟器版本，并判断客户端是否需要更新。当前仅支持 `android` 平台。

请求参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `platform` | string | 否 | 平台，默认 `android` |
| `architecture` | string | 否 | APK 架构：`universal`、`arm64-v8a`、`armeabi-v7a`；默认 `universal`。指定架构没有独立包时回退通用包 |
| `version_code` | uint32 | 否 | 当前客户端版本号 |
| `current_version_code` | uint32 | 否 | 当前客户端版本号，作用同 `version_code` |

响应示例：

```json
{
  "update_available": true,
  "latest": {
    "id": 9,
    "package_id": 12,
    "platform": "android",
    "architecture": "arm64-v8a",
    "version_code": 42,
    "version": "1.2.3",
    "changelog": "更新说明",
    "download_url": "/api/app/v1/emulator/versions/9/download?architecture=arm64-v8a",
    "file_size": 12345678,
    "checksum": "sha256",
    "force_update": false,
    "published_at": "2026-06-14T08:00:00Z"
  }
}
```

没有已发布版本，或当前版本号大于等于最新版本号时：

```json
{
  "update_available": false
}
```

### 4.6 下载安卓模拟器新版本

```http
GET /api/app/v1/emulator/versions/{id}/download
```

下载指定已发布模拟器版本。`id` 为模拟器版本数据库主键，即检测更新接口 `latest.id`。

请求参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | uint | 是 | 路径参数，模拟器版本 ID |
| `architecture` | string | 否 | APK 架构，默认 `universal`；指定架构没有独立包时回退通用包 |

响应：

| 项目 | 说明 |
|------|------|
| HTTP 状态 | `200 OK` |
| Content-Type | `application/vnd.android.package-archive` |
| Content-Disposition | `attachment; filename="xxx.apk"` |
| Body | APK 文件二进制内容 |

响应头：

| Header | 说明 |
|--------|------|
| `X-Emulator-Version-Code` | 模拟器版本号 |
| `X-Emulator-Version` | 模拟器版本号字符串 |
| `X-Emulator-Architecture` | 实际返回的 APK 架构；发生回退时为 `universal` |

指定版本不存在或未发布时返回 `404`。

### 4.7 获取 APP 配置

```http
GET /api/app/v1/config
```

返回 APP 端配置。当前包含 `hosts` 字段，后续新增配置也会追加到该接口响应中。

`hosts` 为后台启用状态的自定义域名解析配置，供模拟器按域名覆盖解析到指定 IP。

响应示例：

```json
{
  "hosts": [
    {
      "domain": "api.example.com",
      "ip": "192.168.1.10:8080"
    }
  ]
}
```

字段说明：

| 字段 | 说明 |
|------|------|
| `hosts` | 域名映射数组 |
| `hosts[].domain` | 域名 |
| `hosts[].ip` | IP，或 `IP:端口`；IPv6 带端口时使用 `[IPv6]:端口` |

## 5. 状态码

| 状态码 | 场景 |
|--------|------|
| `200` | 请求成功 |
| `400` | 参数错误，例如 `q` 为空或路径参数非法 |
| `401` | 签名缺失、签名错误、时间戳过期、Key 错误 |
| `404` | 指定应用、版本、下载包或模拟器版本不存在 |
| `503` | 数据库不可用 |

## 6. 配置项

服务端配置示例：

```yaml
app_api:
  key: "dev-app-key"
  secret: "dev-app-secret-change-me"
  signature_ttl_seconds: 300
```

生产环境必须替换默认 `key` 和 `secret`。
