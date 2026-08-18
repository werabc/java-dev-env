# 树洞后端 API 文档

| 项 | 内容 |
|---|---|
| 文档日期 | 2026-08-18 |
| 后端声明地址 | `http://localhost:8081` |
| 文档状态 | **后端不可达 — 文档为占位/待核实结构** |

---

## 0. 重要说明（必读）

在编写本文档前，已对后端 `http://localhost:8081` 进行实测，结果如下：

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/
# 结果: 000  (Connection refused，端口无监听)
```

- 后端进程在测试沙箱内**未运行**，端口 8081 无任何监听。
- 沙箱内也**不存在后端源码**（无 `pom.xml` / `package.json` / Controller 源文件等），无法通过阅读代码反推真实接口。
- 因此本文件**无法**给出经过实际抓包/源码核实的真实接口列表。

为不耽误后续工作，下方提供一份**树洞类应用常见的接口骨架模板**，所有接口均标记为 **「待核实」**，**不得直接当作真实接口使用**。请按以下任一方式补全真实接口：

1. 在沙箱内启动后端服务后，由我重新抓包核对每一条接口；
2. 提供后端源码 / Swagger(OpenAPI) JSON / 已有接口文档，我据此改写为真实文档。

> 凡是带「⚠️ 待核实」标记的部分，均为基于常见树洞 App 模式的推测结构，**未与实际后端核对**。

## 1. 通用约定（⚠️ 待核实）

| 项 | 推测值 | 核实方式 |
|---|---|---|
| Base URL | `http://localhost:8081` | 服务启动后 `curl http://localhost:8081/` |
| 接口前缀 | `/api` 或 `/api/v1` | 抓包前端请求路径 |
| 数据格式 | `application/json; charset=UTF-8` | 抓包 `Content-Type` |
| 鉴权方式 | `Authorization: Bearer <JWT>` 或 Cookie 会话 | 登录后查看请求头 |
| 时间格式 | ISO-8601 或 Unix 时间戳 | 抓包响应字段 |
| 分页参数 | `page` / `size` 或 `pageNum` / `pageSize` | 抓包列表请求 |
| 错误响应结构 | `{ "code": <int>, "message": "<string>", "data": null }` | 触发一个错误请求观察 |

## 2. 接口清单（⚠️ 全部待核实）

下表为推测接口列表，**实际接口名、参数、返回字段均需以后端为准**。

| 方法 | 路径（推测） | 描述 |
|---|---|---|
| POST | `/api/auth/register` | 用户注册 |
| POST | `/api/auth/login` | 用户登录 |
| POST | `/api/auth/logout` | 退出登录 |
| GET | `/api/auth/me` | 获取当前登录用户 |
| GET | `/api/posts` | 树洞列表（分页） |
| POST | `/api/posts` | 发布树洞 |
| GET | `/api/posts/{id}` | 树洞详情 |
| DELETE | `/api/posts/{id}` | 删除自己的树洞 |
| GET | `/api/posts/{id}/comments` | 帖子评论列表 |
| POST | `/api/posts/{id}/comments` | 发表评论 |
| POST | `/api/posts/{id}/like` | 点赞 / 取消点赞 |
| POST | `/api/posts/{id}/favorite` | 收藏 / 取消收藏 |
| GET | `/api/users/{id}` | 用户主页 |
| GET | `/api/users/me/profile` | 个人资料 |
| PUT | `/api/users/me/profile` | 修改个人资料 |
| GET | `/api/search?q=` | 关键字搜索 |
| GET | `/api/tags/{tag}/posts` | 按标签筛帖 |
| GET | `/api/categories` | 分类列表 |
| POST | `/api/upload` | 上传图片/附件 |

## 3. 接口详情模板（⚠️ 待核实）

> 以下每个接口的字段均为**示例**，并非真实返回。请以后端实际响应为准。

### 3.1 用户注册 ⚠️

```
POST /api/auth/register
Content-Type: application/json
```

请求体（示例）：
```json
{ "username": "string", "password": "string", "email": "string" }
```

响应（示例）：
```json
{ "code": 0, "message": "ok", "data": { "userId": 0, "token": "string" } }
```

### 3.2 用户登录 ⚠️

```
POST /api/auth/login
Content-Type: application/json
```

请求体（示例）：
```json
{ "username": "string", "password": "string" }
```

响应（示例）：
```json
{ "code": 0, "message": "ok", "data": { "token": "string", "expiresIn": 0 } }
```

### 3.3 树洞列表 ⚠️

```
GET /api/posts?page=1&size=20&tag=&sort=latest
Authorization: Bearer <token>
```

响应（示例）：
```json
{
  "code": 0, "message": "ok",
  "data": {
    "total": 0, "page": 1, "size": 20,
    "records": [
      { "id": 0, "authorId": 0, "authorName": "string",
        "content": "string", "images": ["string"],
        "likeCount": 0, "commentCount": 0, "favoriteCount": 0,
        "createdAt": "2026-08-18T00:00:00Z" }
    ]
  }
}
```

### 3.4 发布树洞 ⚠️

```
POST /api/posts
Authorization: Bearer <token>
Content-Type: application/json
```

请求体（示例）：
```json
{ "content": "string", "images": ["string"], "tag": "string", "anonymous": true }
```

### 3.5 树洞详情 ⚠️

```
GET /api/posts/{id}
Authorization: Bearer <token>
```

### 3.6 评论列表 / 发表评论 ⚠️

```
GET /api/posts/{id}/comments?page=1&size=20
POST /api/posts/{id}/comments   { "content": "string", "parentId": 0 }
```

### 3.7 点赞 / 收藏 ⚠️

```
POST /api/posts/{id}/like        -> { "liked": true, "likeCount": 0 }
POST /api/posts/{id}/favorite    -> { "favorited": true, "favoriteCount": 0 }
```

### 3.8 用户主页 / 个人资料 ⚠️

```
GET  /api/users/{id}
GET  /api/users/me/profile
PUT  /api/users/me/profile   { "nickname": "string", "avatar": "string", "bio": "string" }
```

### 3.9 搜索 / 标签 / 分类 ⚠️

```
GET /api/search?q=keyword&page=1&size=20
GET /api/tags/{tag}/posts
GET /api/categories
```

### 3.10 上传 ⚠️

```
POST /api/upload   multipart/form-data, field: file
-> { "code": 0, "data": { "url": "string" } }
```

## 4. 错误码（⚠️ 待核实）

| code | 含义（推测） |
|---|---|
| 0 | 成功 |
| 40001 / 401 | 未登录 / token 失效 |
| 40300 / 403 | 无权限 |
| 40400 / 404 | 资源不存在 |
| 50000 / 500 | 服务器内部错误 |

> 真实错误码体系以后端源码或响应实际 `code` 字段为准。

## 5. 真实化步骤（建议在后端可达后执行）

1. 启动后端，确认 `curl http://localhost:8081/` 有响应。
2. 若后端集成了 Swagger/OpenAPI：抓取 `/v3/api-docs` 或 `/swagger-ui/index.html` 获取真实接口规格，直接替换本文档全部"待核实"内容。
3. 若无 Swagger：用浏览器正常使用一遍用户端，抓取 Network 中所有 XHR/Fetch 请求，按真实路径/参数/响应字段逐条改写本文档。
4. 触发若干边界场景（未登录访问、参数缺失、无权限），记录真实错误码并补充到 §4。

> 在完成上述核实前，**本文档不可作为前后端对接的正式依据**。
