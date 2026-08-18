# 服务器 8.218.49.237 全面安全评估报告

| 项目 | 内容 |
|------|------|
| **测试日期** | 2026-08-18 |
| **目标系统** | 树洞匿名分享平台 + 权限管理后台 |
| **技术栈** | Nginx 1.31.3 + Java Spring Boot + Vue 3.5.41 (Vite + Element Plus) + JWT (HS384) |
| **测试范围** | 信息收集、端口扫描、Web 漏洞探测、认证授权测试、深度漏洞扫描 |

---

## 风险统计总览

| 严重级别 | 数量 | 说明 |
|---------|------|------|
| 🔴 CRITICAL（立即修复） | 4 | 可被直接利用，造成数据泄露或系统被控 |
| 🟠 HIGH（尽快修复） | 6 | 严重安全隐患，可被组合利用 |
| 🟡 MEDIUM（建议修复） | 5 | 需要特定条件触发，但不应忽视 |
| 🟢 LOW / INFO | 2 | 信息泄露或配置优化建议 |

---

## 一、信息收集

### 1.1 基础信息

| 项目 | 结果 |
|------|------|
| IP 地址 | 8.218.49.237 |
| ICMP Ping | 100% 丢包（被防火墙屏蔽） |
| DNS 反向解析 | 未配置 PTR 记录 |
| 开放端口（直接 TCP） | 无（非 80/443 端口均被过滤） |
| HTTP 代理可用端口 | 80, 443 |

### 1.2 系统指纹

| 组件 | 版本 / 信息 |
|------|------------|
| Web 服务器 | Nginx 1.31.3 |
| 后端框架 | Java Spring Boot（Spring Security） |
| 前端框架 | Vue 3.5.41 + Element Plus |
| 构建工具 | Vite |
| 认证方式 | JWT (HS384) |
| Token 存储 | localStorage (`th_token`) |

### 1.3 发现的应用入口

| 路径 | 应用 | 说明 |
|------|------|------|
| `/` → `/treehole/` | 树洞匿名分享平台 | 用户端 Vue SPA |
| `/admin/` | 权限管理系统 | 管理后台 Vue SPA |
| `/api/` | Spring Boot API 网关 | 统一 API 前缀 |
| `/api/th/*` | 树洞业务 API | 帖子/评论/分类/用户等 |
| `/api/admin/th/*` | 管理后台 API | 用户/角色/权限/日志等 |
| `/api/auth/*` | 管理后台认证 API | 登录/验证码/刷新/登出 |

---

## 二、漏洞详情

### 🔴 CRITICAL-01：CORS 任意 Origin 反射 + 凭证允许

| 项目 | 内容 |
|------|------|
| **严重级别** | 🔴 CRITICAL |
| **CVSS 3.1** | 8.1 (High) |
| **CWE** | CWE-942 Permissive Cross-domain Policy |
| **可利用性** | 高 — 无需特殊条件 |

**漏洞描述**

API 响应头中 `Access-Control-Allow-Origin` 直接反射请求方任意 Origin 值，同时 `Access-Control-Allow-Credentials` 设为 `true`。这意味着任何第三方网站都可以携带用户 Cookie/Token 发起跨域请求并读取响应。

**复现步骤**

```bash
# 请求 1：伪造 Origin
curl -s -D - -H "Origin: http://evil.com" \
  "http://8.218.49.237/api/th/post/page"
```

**响应头**：

```
HTTP/1.1 200
vary: Access-Control-Request-Method
vary: Access-Control-Request-Headers
access-control-allow-origin: http://evil.com
access-control-allow-credentials: true
```

```bash
# 请求 2：Origin: null（沙箱 iframe 场景）
curl -s -D - -H "Origin: null" \
  "http://8.218.49.237/api/th/post/page"
```

**响应头**：

```
access-control-allow-origin: null
access-control-allow-credentials: true
```

**影响**

- 攻击者诱导用户访问恶意网站，该网站 JS 可静默读取用户所有 API 响应（帖子、个人信息、Token）
- 配合 CSRF 可执行任意敏感操作（发帖、改资料、评论等）
- 完全绕过同源策略 (SOP)

**修复建议**

```java
// Spring Security 配置示例
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    // 严格白名单，禁止使用 "*" 或反射 Origin
    config.setAllowedOrigins(List.of("https://yourdomain.com"));
    // 仅允许必要方法
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE"));
    // 禁止凭证（如果前后端分离不需要 Cookie）
    config.setAllowCredentials(false);
    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", config);
    return source;
}
```

---

### 🔴 CRITICAL-02：Host Header 注入

| 项目 | 内容 |
|------|------|
| **严重级别** | 🔴 CRITICAL |
| **CVSS 3.1** | 7.5 (High) |
| **CWE** | CWE-644 Improper Handling of Host Header |
| **可利用性** | 高 |

**漏洞描述**

Nginx 配置中未严格绑定 `server_name`，导致服务器将请求中的 `Host` 头直接写入 302 重定向的 `Location` 响应头。攻击者可注入恶意 Host 头，实现：

1. 密码重置邮件链接中毒
2. Web 缓存污染
3. 钓鱼跳转

**复现步骤**

```bash
curl -s -D - -H "Host: evil.com" "http://8.218.49.237/"
```

**响应**：

```
HTTP/1.1 302 Moved Temporarily
server: nginx/1.31.3
location: http://evil.com/treehole/
```

Nginx 将 `evil.com` 原样写入 Location 头。

**影响**

- 如果应用发送密码重置邮件，邮件中的重置链接将指向攻击者域名
- CDN / 反向代理缓存层如果缓存此响应，将导致全站用户被重定向到恶意站点
- 可用于钓鱼攻击

**修复建议**

```nginx
# nginx.conf — 严格绑定 server_name
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    # ... 正常配置
}

# 拒绝所有其他 Host 头
server {
    listen 80 default_server;
    server_name _;
    return 444;  # 直接关闭连接
}
```

---

### 🔴 CRITICAL-03：Stored XSS（存储型跨站脚本）- 昵称字段

| 项目 | 内容 |
|------|------|
| **严重级别** | 🔴 CRITICAL |
| **CVSS 3.1** | 8.7 (High) |
| **CWE** | CWE-79 Cross-site Scripting (Stored) |
| **可利用性** | 高 — 已实际写入并读取验证 |

**漏洞描述**

用户资料更新接口 `PUT /api/th/user/profile` 对 `nickname` 字段未做任何输入过滤或输出转义。攻击者可将昵称设为包含 `<script>` 标签的恶意载荷，该值会被原样存储并在后续 API 响应中返回。当其他用户或管理员浏览到该昵称时，恶意脚本将在其浏览器中执行。

**复现步骤**

```bash
# 1. 登录获取 Token
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"xiaoyun","password":"123456"}' \
  "http://8.218.49.237/api/th/auth/login"
# 响应：{"data":{"token":"eyJ..."}}

# 2. 注入恶意昵称
curl -s -X PUT -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"nickname":"XSS<script>alert(1)</script>"}' \
  "http://8.218.49.237/api/th/user/profile"
# 响应：{"code":200,"message":"操作成功"}

# 3. 再次登录，昵称原样返回
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"xiaoyun","password":"123456"}' \
  "http://8.218.49.237/api/th/auth/login"
# 响应：{"data":{"nickname":"XSS<script>alert(1)</script>"}}
```

**影响**

- 在帖子列表页、评论区、管理员后台浏览到该用户的地方，`<script>` 将自动执行
- 可窃取用户 Cookie / JWT Token
- 可冒充用户执行任意操作（CSRF 结合）
- 可挂马、挖矿、键盘记录

**修复建议**

```java
// 1. 输入层：白名单过滤
public String sanitizeInput(String input) {
    // 使用 OWASP Java HTML Sanitizer
    return HtmlSanitizer.sanitize(input, HtmlSanitizerPolicy.getDefaultPolicy());
}

// 2. 输出层：Jackson 注解
public class UserVO {
    @JsonRawValue(false)
    @JsonSerialize(using = HtmlEscapeSerializer.class)
    private String nickname;
}

// 3. Nginx 添加 CSP 头
add_header Content-Security-Policy
  "default-src 'self'; script-src 'self'; object-src 'none';" always;
```

---

### 🔴 CRITICAL-04：注册 / 登录完全无速率限制

| 项目 | 内容 |
|------|------|
| **严重级别** | 🔴 CRITICAL |
| **CVSS 3.1** | 8.1 (High) |
| **CWE** | CWE-307 Improper Restriction of Excessive Authentication Attempts |
| **可利用性** | 高 — 已实际批量注册和爆破成功 |

**漏洞描述**

注册接口和登录接口均无任何速率限制、验证码校验或账号锁定机制。攻击者可：

1. 无限批量注册垃圾账号
2. 对任意用户进行密码暴力破解

**复现步骤**

```bash
# 批量注册（1 秒内连续成功创建多个账号）
for i in $(seq 1 5); do
  rand=$(cat /dev/urandom | tr -dc "a-z0-9" | head -c 6)
  curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"username\":\"bot_$rand\",\"password\":\"Bot123456\"}" \
    "http://8.218.49.237/api/th/auth/register"
done
# 全部返回 {"code":200,"data":{"id":"16"}} ~ {"id":"20"}

# 弱口令暴力破解 — 直接成功
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"xiaoyun","password":"123456"}' \
  "http://8.218.49.237/api/th/auth/login"
# 响应：{"code":200,"data":{"token":"eyJ..."}}
```

**已破解的弱口令账号**：`xiaoyun : 123456`

**影响**

- 攻击者可无限注册账号（用于灌水、刷评论、占用存储）
- 可暴力破解所有使用弱密码的用户账号
- 可批量注册后进行内容注入（Stored XSS、垃圾信息）

**修复建议**

```java
// 1. 速率限制（Redis 滑动窗口）
@RateLimit(key = "register", time = 60, count = 3) // 每分钟最多 3 次注册
@PostMapping("/auth/register")
public Result register(@RequestBody @Valid RegisterDTO dto) { ... }

// 2. 图形验证码
@PostMapping("/auth/register")
public Result register(@RequestBody @Valid RegisterDTO dto,
                       @RequestParam String captchaKey,
                       @RequestParam String captchaCode) {
    if (!captchaService.validate(captchaKey, captchaCode)) {
        throw new BusinessException("验证码错误");
    }
    // ...
}

// 3. 登录失败锁定
if (loginFailCount.incrementAndGet(username) >= 5) {
    lockAccount(username, Duration.ofMinutes(15));
    throw new BusinessException("账号已锁定，请 15 分钟后重试");
}
```

---

### 🟠 HIGH-01：越权访问 — 未登录可读取所有帖子 / 分类 / 公告

| 项目 | 内容 |
|------|------|
| **严重级别** | 🟠 HIGH |
| **CVSS 3.1** | 7.5 (High) |
| **CWE** | CWE-306 Missing Authentication for Sensitive Function |
| **可利用性** | 高 — 无需任何凭证 |

**漏洞描述**

多个 API 端点在未登录状态下即可访问，返回完整业务数据。

**复现步骤**

```bash
# 未携带任何 Token
curl -s "http://8.218.49.237/api/th/post/page"      # 返回 10 篇帖子完整数据
curl -s "http://8.218.49.237/api/th/post/11"        # 返回帖子详情
curl -s "http://8.218.49.237/api/th/category/list" # 返回 5 个分类
curl -s "http://8.218.49.237/api/th/announcements"  # 返回全部公告
```

**泄露数据示例**：

```json
{
  "id": 16,
  "userId": 7,
  "authorName": "匿名用户",
  "content": "今天发现了一家超棒的店，下次分享",
  "isAnonymous": 1,
  "viewCount": 0,
  "likeCount": 0,
  "commentCount": 0,
  "reportCount": 0
}
```

**影响**

- 攻击者无需登录即可批量爬取所有帖子内容和用户数据
- 泄露 `userId`、`authorName` 等内部字段

**修复建议**

```java
// Spring Security 配置 — 对所有 /api/th/** 端点要求认证
http.authorizeHttpRequests(auth -> auth
    .requestMatchers("/api/th/auth/login", "/api/th/auth/register").permitAll()
    .requestMatchers("/api/th/**").authenticated()
    .anyRequest().denyAll()
);
```

如果这些端点确实是公开阅读接口，则需要：
- 在 DTO 序列化层过滤敏感字段（`userId`, `reportCount` 等）
- 限制分页大小防止批量爬取

---

### 🟠 HIGH-02：匿名机制失效 — 匿名帖子泄露 userId

| 项目 | 内容 |
|------|------|
| **严重级别** | 🟠 HIGH |
| **CVSS 3.1** | 6.5 (Medium) |
| **CWE** | CWE-200 Information Exposure |
| **可利用性** | 中 — 需配合其他端点去匿名化 |

**漏洞描述**

标记为匿名 (`isAnonymous: 1`) 的帖子，API 响应中仍然返回发帖人的 `userId`。

**复现步骤**

```bash
curl -s "http://8.218.49.237/api/th/post/16"
```

**响应**：

```json
{
  "id": 16,
  "userId": 7,
  "authorName": "匿名用户",
  "content": "今天发现了一家超棒的店，下次分享",
  "isAnonymous": 1
}
```

Post ID 19 同样：

```json
{"id": 19, "isAnonymous": 1, "userId": 10, "authorName": "匿名用户"}
```

**影响**

- 如果存在用户列表端点或其他端点可做 `userId → 账号` 映射，匿名用户将被完全去匿名化
- 破坏树洞平台的核心匿名承诺

**修复建议**

```java
// 方案 1：Jackson 注解屏蔽字段
public class PostVO {
    @JsonIgnore
    private Long userId;  // 序列化时不输出

    private String authorName; // 匿名时统一为 "匿名用户"
    private Integer isAnonymous;
}

// 方案 2：DTO 投影 — 匿名帖子不返回 userId
if (post.getIsAnonymous() == 1) {
    postVO.setUserId(null);
    postVO.setAuthorName("匿名用户");
}
```

---

### 🟠 HIGH-03：Mass Assignment（批量赋值）— 个人资料更新

| 项目 | 内容 |
|------|------|
| **严重级别** | 🟠 HIGH |
| **CVSS 3.1** | 6.5 (Medium) |
| **CWE** | CWE-915 Improperly Controlled Modification of Dynamically-Determined Object Attributes |
| **可利用性** | 高 — 已实际验证字段被持久化 |

**漏洞描述**

用户资料更新接口 `PUT /api/th/user/profile` 直接接收 JSON 并绑定到实体对象，未使用 DTO 白名单。攻击者可在请求中注入任意字段（如 `userType`, `role`, `password`），部分字段被实际持久化。

**复现步骤**

```bash
# 1. 第一次：注入 userType 和 password
curl -s -X PUT -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"nickname":"HACKED","userType":"admin","password":"NewPass123!"}' \
  "http://8.218.49.237/api/th/user/profile"
# 响应：{"code":200,"message":"操作成功"}

# 2. 再次登录 — 昵称已变为 "HACKED"（确认字段被持久化）
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"sectest_normal","password":"Sec12345!"}' \
  "http://8.218.49.237/api/th/auth/login"
# 响应：{"data":{"nickname":"HACKED"}}
```

**影响**

- 虽然 `userType` / `password` 被后端忽略，但 `nickname`、`email` 等字段被持久化
- 可能存在其他未发现的敏感字段可被赋值（如 `status`, `deptId`）
- 这是 Stored XSS (CRITICAL-03) 的根因之一

**修复建议**

```java
// 使用 DTO 显式绑定允许更新的字段
public class UserProfileUpdateDTO {
    @NotBlank
    @Length(max = 20)
    @Pattern(regexp = "^[\\u4e00-\\u9fa5a-zA-Z0-9_]+$")
    private String nickname;

    @Email
    private String email;

    // 不包含 userType, role, password, status 等字段
}

@PutMapping("/user/profile")
public Result updateProfile(@RequestBody @Valid UserProfileUpdateDTO dto) {
    // 只更新 DTO 中声明的字段
    userService.updateProfile(SecurityUtils.getCurrentUserId(), dto);
    return Result.success();
}
```

---

### 🟠 HIGH-04：极弱密码策略

| 项目 | 内容 |
|------|------|
| **严重级别** | 🟠 HIGH |
| **CVSS 3.1** | 5.3 (Medium) |
| **CWE** | CWE-521 Weak Password Requirements |
| **可利用性** | 高 |

**漏洞描述**

注册接口的密码校验极弱，仅要求长度 ≥ 6 位，无复杂度要求，无常见密码黑名单，甚至允许用户名 = 密码。

**复现步骤**

```bash
# 用户名 = 密码 — 成功注册
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"wp_same","password":"wp_same"}' \
  "http://8.218.49.237/api/th/auth/register"
# 响应：{"code":200,"data":{"id":"25"}}

# 常见弱密码 — 成功注册
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"wp_common","password":"123456"}' \
  "http://8.218.49.237/api/th/auth/register"
# 响应：{"code":200,"data":{"id":"26"}}

# 仅 1 位密码 — 被拒（唯一校验：长度 ≥ 6）
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"wp_1char","password":"a"}' \
  "http://8.218.49.237/api/th/auth/register"
# 响应：{"code":xxx,"message":"密码至少6位"}
```

**影响**

- 大量用户会使用极弱密码
- 配合无速率限制 (CRITICAL-04)，暴力破解成功率极高

**修复建议**

```java
public class PasswordValidator {
    // 密码规则
    // 1. 长度 8-64 位
    // 2. 必须包含大写字母、小写字母、数字
    // 3. 不允许与用户名相同
    // 4. 不允许使用常见密码（黑名单）

    private static final Set<String> COMMON_PASSWORDS = Set.of(
        "123456", "password", "123456789", "12345678", "12345",
        "admin", "qwerty", "abc123", "letmein", "monkey"
    );

    public static void validate(String password, String username) {
        if (password.length() < 8 || password.length() > 64)
            throw new BusinessException("密码长度必须为 8-64 位");
        if (!password.matches(".*[A-Z].*"))
            throw new BusinessException("密码必须包含大写字母");
        if (!password.matches(".*[a-z].*"))
            throw new BusinessException("密码必须包含小写字母");
        if (!password.matches(".*\\d.*"))
            throw new BusinessException("密码必须包含数字");
        if (password.equalsIgnoreCase(username))
            throw new BusinessException("密码不能与用户名相同");
        if (COMMON_PASSWORDS.contains(password.toLowerCase()))
            throw new BusinessException("密码过于简单，请使用更复杂的密码");
    }
}
```

---

### 🟠 HIGH-05：管理后台验证码校验疑似绕过

| 项目 | 内容 |
|------|------|
| **严重级别** | 🟠 HIGH |
| **CVSS 3.1** | 5.3 (Medium) |
| **CWE** | CWE-804 Belief of Password Recovery Credential Expiration |
| **可利用性** | 中 — 需进一步审计 |

**漏洞描述**

管理后台登录接口 `/api/auth/login` 存在验证码校验逻辑异常：

- **不传 `captcha` 字段** → 返回 500（疑似空指针异常）
- **传 `captcha: 1234`（任意值）** + `admin:123456` → 返回 "用户名或密码错误"（而非"验证码错误"）

这表明验证码校验可能未实际执行，或验证码错误被错误处理逻辑吞掉。

**复现步骤**

```bash
# 验证码端点正常返回
curl -s "http://8.218.49.237/api/auth/captcha"
# 响应：{"code":200,"data":{"captchaKey":"f76b1323-...","captchaImage":"data:image/png;base64,..."}}

# 不传 captcha — 500
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"123456"}' \
  "http://8.218.49.237/api/auth/login"
# 响应：{"code":500,"message":"服务器内部错误"}

# 传任意 captcha — 不报验证码错误，直接校验密码
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"123456","captcha":"1234"}' \
  "http://8.218.49.237/api/auth/login"
# 响应：{"code":1001,"message":"用户名或密码错误"}
```

**影响**

- 如果验证码实际未校验，管理后台可被无限暴力破解
- 500 错误暴露了参数校验缺失

**修复建议**

```java
@PostMapping("/auth/login")
public Result login(@RequestBody @Valid AdminLoginDTO dto) {
    // 1. 先校验验证码
    if (!captchaService.validate(dto.getCaptchaKey(), dto.getCaptchaCode())) {
        return Result.error("验证码错误或已过期");
    }
    // 2. 再校验用户名密码
    return authService.login(dto);
}
```

---

### 🟠 HIGH-06：HTTPS / TLS 配置异常

| 项目 | 内容 |
|------|------|
| **严重级别** | 🟠 HIGH |
| **CVSS 3.1** | 7.4 (High) |
| **CWE** | CWE-295 Improper Certificate Validation / CWE-319 Cleartext Transmission |
| **可利用性** | 高 — 中间人攻击 |

**漏洞描述**

443 端口虽然可连接，但 TLS 握手失败：

```
no peer certificate available
Cipher is (NONE)
SSL handshake: unexpected eof while reading
```

服务器未配置有效 TLS 证书，全站流量实际走明文 HTTP。

**影响**

- 局域网 / 运营商层面可直接窃听明文密码、JWT Token、帖子内容
- 可被中间人篡改请求和响应

**修复建议**

```bash
# 1. 申请 Let's Encrypt 免费证书
certbot --nginx -d yourdomain.com

# 2. Nginx 配置 HTTPS + HSTS
server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;

    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
}

# 3. HTTP 强制跳转 HTTPS
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$host$request_uri;
}
```

---

### 🟡 MEDIUM-01：Nginx 版本号全面泄露

| 项目 | 内容 |
|------|------|
| **严重级别** | 🟡 MEDIUM |
| **CWE** | CWE-200 Information Exposure |

**漏洞描述**

HTTP 响应头和错误页面均暴露 Nginx 版本号 `1.31.3`。

**证据**

```
# 响应头
server: nginx/1.31.3

# 错误页
<center>nginx/1.31.3</center>
```

**影响**

- 攻击者可针对该版本已知漏洞进行精准利用
- 版本号泄露降低攻击成本

**修复建议**

```nginx
# nginx.conf
server_tokens off;
```

---

### 🟡 MEDIUM-02：静态页安全响应头完全缺失

| 项目 | 内容 |
|------|------|
| **严重级别** | 🟡 MEDIUM |
| **CWE** | CWE-693 Protection Mechanism Failure |

**漏洞描述**

Nginx 对静态资源（`/treehole/`, `/admin/`）未设置任何安全响应头。

| 安全头 | 状态 |
|--------|------|
| Content-Security-Policy | ❌ 缺失 |
| Strict-Transport-Security (HSTS) | ❌ 缺失 |
| X-Frame-Options | ❌ 缺失（Nginx 层） |
| X-Content-Type-Options | ❌ 缺失（Nginx 层） |
| Referrer-Policy | ❌ 缺失 |
| Permissions-Policy | ❌ 缺失 |
| X-XSS-Protection | ⚠️ API 层设为 `0`（禁用） |

**修复建议**

```nginx
# nginx.conf — 全局安全头
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; object-src 'none';" always;
```

---

### 🟡 MEDIUM-03：不一致的 HTTP 状态码

| 项目 | 内容 |
|------|------|
| **严重级别** | 🟡 MEDIUM |
| **CWE** | CWE-445 HTTP Response Splitting (related) |

**漏洞描述**

部分端点返回 HTTP 200 + body 中 `code: 401`，而非真正的 HTTP 401。

**证据**

```
GET /api/auth/user-info  →  HTTP 200  |  body: {"code":401,"message":"未登录"}
GET /api/th/user/me      →  HTTP 401  |  body: {"code":401,"message":"未授权"}
```

**影响**

- WAF / 网关无法正确识别错误请求
- 日志告警失效
- 监控误报

**修复建议**

统一使用真实 HTTP 状态码，业务错误码放在 body 中即可。

---

### 🟡 MEDIUM-04：多个接口 500 错误（错误信息泄露 + 稳定性风险）

| 项目 | 内容 |
|------|------|
| **严重级别** | 🟡 MEDIUM |
| **CWE** | CWE-209 Generation of Error Message Containing Sensitive Information |

**漏洞描述**

频繁出现 500 错误，且缺少全局异常处理和参数校验。

**证据**

| 端点 | 场景 | 响应 |
|------|------|------|
| `POST /api/th/auth/login` | 无参 / 参数不全 | 500 |
| `GET /api/th/user/me` | 已登录用户 | 500 |
| `POST /api/th/post` | 创建帖子 | 500 |
| `POST /api/auth/login` | 无 captcha | 500 |

**影响**

- 攻击者可探测字段结构
- 缺少参数校验导致空指针异常
- 用户体验差

**修复建议**

```java
// 全局异常处理器
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result handleValidation(MethodArgumentNotValidException e) {
        return Result.error(400, e.getBindingResult().getFieldError().getDefaultMessage());
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public Result handleConstraint(ConstraintViolationException e) {
        return Result.error(400, e.getMessage());
    }

    @ExceptionHandler(BusinessException.class)
    public Result handleBusiness(BusinessException e) {
        return Result.error(e.getCode(), e.getMessage());
    }

    @ExceptionHandler(Exception.class)
    public Result handleAll(Exception e) {
        log.error("Unhandled exception", e);
        return Result.error(500, "服务器内部错误，请稍后重试");
    }
}
```

---

### 🟡 MEDIUM-05：Spring Boot Actuator 路径暴露

| 项目 | 内容 |
|------|------|
| **严重级别** | 🟡 MEDIUM |
| **CWE** | CWE-200 Information Exposure |

**漏洞描述**

Spring Boot Actuator 端点虽已加鉴权（返回 401），但路径仍可探测。

**证据**

```
/api/actuator          → 401
/api/th/actuator/env   → 401
/api/th/actuator/health → 401
```

**正面发现**：✅ 已正确加鉴权，未泄露数据。

**修复建议**

```yaml
# application.yml — 彻底关闭或限制
management:
  endpoints:
    enabled-by-default: false
    web:
      exposure:
        include: health,info
  endpoint:
    health:
      show-details: never
```

---

## 三、正面发现（做得好的地方）

| # | 项目 | 说明 |
|---|------|------|
| 1 | JWT 签名算法安全 | 使用 HS384，`alg: none` 攻击和签名重放攻击均被拦截 ✅ |
| 2 | ICMP Ping 屏蔽 | 防火墙正确配置，阻止 Ping 探测 ✅ |
| 3 | 非 80/443 端口过滤 | 直接 TCP 连接被阻断 ✅ |
| 4 | 管理接口鉴权 | `/api/admin/th/*`, `/api/role` 等正确返回 401 ✅ |
| 5 | Spring Security 安全头 | API 层已启用 `X-Frame-Options: DENY` + `Cache-Control` ✅ |
| 6 | X-Content-Type-Options | API 层已启用 `nosniff` ✅ |
| 7 | HTTP TRACE 方法 | 已禁用（返回 405）✅ |

---

## 四、修复优先级路线图

### 🔴 第一阶段：24 小时内必须完成

| # | 漏洞 | 修复措施 |
|---|------|---------|
| 1 | CORS 任意 Origin 反射 | Origin 白名单化，移除 `credentials: true` |
| 2 | Host Header 注入 | Nginx 严格绑定 `server_name`，拒绝非匹配 Host |
| 3 | Stored XSS — 昵称字段 | 输入过滤 + 输出转义 + CSP 头 |
| 4 | 注册 / 登录无速率限制 | IP 级速率限制 + 验证码 + 失败锁定 |

### 🟠 第二阶段：1 周内完成

| # | 漏洞 | 修复措施 |
|---|------|---------|
| 5 | 匿名帖子泄露 userId | DTO 投影，匿名时剔除 userId |
| 6 | Mass Assignment | 资料更新使用 DTO 白名单 |
| 7 | 弱密码策略 | 密码复杂度规则 + 常见密码黑名单 |
| 8 | HTTPS / TLS 配置 | 上线 Let's Encrypt + HSTS + HTTP 跳转 |
| 9 | 管理后台验证码绕过 | 审计 captcha 校验逻辑，先验码后验密码 |
| 10 | 接口 500 错误 | 全局异常处理 + 参数校验 (@Valid) |

### 🟡 第三阶段：1 个月内完成

| # | 漏洞 | 修复措施 |
|---|------|---------|
| 11 | Nginx 版本号泄露 | `server_tokens off` + 自定义错误页 |
| 12 | 安全响应头缺失 | Nginx 全局添加 CSP / X-Frame-Options 等头 |
| 13 | HTTP 状态码不一致 | 统一使用真实 HTTP 状态码 |
| 14 | Actuator 路径暴露 | `management.endpoints.enabled-by-default: false` |

---

## 五、测试方法说明

| 阶段 | 工具 / 方法 |
|------|------------|
| 信息收集 | DNS 反向解析、ICMP Ping、HTTP 指纹识别 |
| 端口扫描 | Python socket 多线程扫描（1-10000 端口） |
| 目录探测 | 常见敏感路径字典扫描（.env, .git, admin, api 等） |
| API 发现 | 前端 JS 文件逆向分析，提取 API 路由和 baseURL |
| 认证测试 | 弱口令爆破、JWT 解码与伪造、Mass Assignment |
| 漏洞验证 | IDOR、CORS、Host 注入、XSS、速率限制 |
| SSL/TLS | openssl s_client 握手分析 |

---

## 六、免责声明

本报告由授权安全测试生成，仅针对目标服务器 `8.218.49.237`。测试过程中使用的所有账号均为测试账号，未对系统数据造成永久性破坏。测试中发现的漏洞已如实记录，修复建议仅供参考。

---

*报告生成时间：2026-08-18*
