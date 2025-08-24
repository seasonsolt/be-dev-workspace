# Railway 部署配置指南

Railway 是现代化的部署平台，支持从 GitHub 自动部署。以下是 Ginkgoo AI 微服务在 Railway 上的部署配置。

## 🚄 Railway 环境变量配置

### 核心原则
- **本地开发**: 使用 `.env` 文件 (不提交到 Git)
- **Railway 部署**: 使用 Railway Variables 面板配置
- **代码适配**: Spring Boot 同时支持两种方式

## 📋 各服务环境变量配置

### 1. core-identity (端口 9000)

在 Railway Variables 中配置：

```bash
# Database - Railway PostgreSQL
POSTGRES_HOST=your-railway-postgres-host
POSTGRES_PORT=5432
POSTGRES_DB=railway
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your-railway-postgres-password
POSTGRES_SCHEMA=identity

# Redis - Railway Redis
REDIS_HOST=your-railway-redis-host
REDIS_PORT=6379
REDIS_PASSWORD=your-railway-redis-password

# Service Configuration
SERVER_PORT=9000
SERVICE_HOST=0.0.0.0
SERVICE_BASE_URL=https://your-identity-service.railway.app

# OAuth2 Configuration
OAUTH2_ISSUER_URL=https://your-identity-service.railway.app
OAUTH2_JWK_SET_URI=https://your-identity-service.railway.app/.well-known/jwks.json

# Inter-Service Communication (Railway 内部)
CORE_WORKSPACE_URI=https://your-workspace-service.railway.app
CORE_GATEWAY_URI=https://your-gateway-service.railway.app

# Email Configuration
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password

# Social Login
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret

# Security
ADMIN_API_KEY=your-secure-admin-key

# Logging
LOGGING_LEVEL_ROOT=INFO
LOGGING_LEVEL_GINKGOOAI=INFO
```

### 2. be-legal-case (端口 8083)

```bash
# Database
POSTGRES_HOST=your-railway-postgres-host
POSTGRES_PORT=5432
POSTGRES_DB=railway
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your-railway-postgres-password
POSTGRES_SCHEMA=legalcase

# Redis
REDIS_HOST=your-railway-redis-host
REDIS_PORT=6379
REDIS_PASSWORD=your-railway-redis-password

# Service Configuration
SERVER_PORT=8083
SERVICE_HOST=0.0.0.0
SERVICE_BASE_URL=https://your-legalcase-service.railway.app

# Inter-Service Communication
CORE_IDENTITY_URI=https://your-identity-service.railway.app
CORE_WORKSPACE_URI=https://your-workspace-service.railway.app
BE_CORE_STORAGE_URI=https://your-storage-service.railway.app
BE_CORE_MESSAGING_URI=https://your-messaging-service.railway.app
BE_CORE_INTELLIGENCE_URI=https://your-intelligence-service.railway.app

# OAuth2
AUTH_SERVER=https://your-identity-service.railway.app
OAUTH2_ISSUER_URL=https://your-identity-service.railway.app
OAUTH2_JWK_SET_URI=https://your-identity-service.railway.app/.well-known/jwks.json

# AI Configuration
OPENAI_API_KEY=your-openai-api-key
OPENROUTER_API_KEY=your-openrouter-api-key

# Logging
LOGGING_LEVEL_ROOT=INFO
LOGGING_LEVEL_GINKGOOAI=INFO
```

### 3. core-workspace (端口 8082)

```bash
# Database
POSTGRES_HOST=your-railway-postgres-host
POSTGRES_PORT=5432
POSTGRES_DB=railway
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your-railway-postgres-password
POSTGRES_SCHEMA=workspace

# Redis
REDIS_HOST=your-railway-redis-host
REDIS_PORT=6379
REDIS_PASSWORD=your-railway-redis-password

# Service Configuration
SERVER_PORT=8082
SERVICE_HOST=0.0.0.0
SERVICE_BASE_URL=https://your-workspace-service.railway.app

# Inter-Service Communication
CORE_IDENTITY_URI=https://your-identity-service.railway.app

# OAuth2
AUTH_SERVER=https://your-identity-service.railway.app
OAUTH2_ISSUER_URL=https://your-identity-service.railway.app
OAUTH2_JWK_SET_URI=https://your-identity-service.railway.app/.well-known/jwks.json

# Logging
LOGGING_LEVEL_ROOT=INFO
LOGGING_LEVEL_GINKGOOAI=INFO
```

## 🔧 Railway 部署配置

### 1. 项目结构

每个微服务作为单独的 Railway 项目部署：

```
Railway Dashboard:
├── ginkgoo-core-identity     (core-identity/)
├── ginkgoo-core-workspace    (core-workspace/)
├── ginkgoo-be-legal-case     (be-legal-case/)
├── ginkgoo-core-gateway      (core-gateway/)
├── ginkgoo-be-core-storage   (be-core-storage/)
├── ginkgoo-be-core-messaging (be-core-messaging/)
└── ginkgoo-be-core-intelligence (be-core-intelligence/)
```

### 2. 构建配置

为每个服务创建 `railway.toml`:

#### core-identity/railway.toml
```toml
[build]
builder = "nixpacks"

[deploy]
startCommand = "java -jar target/server.jar"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

[[services]]
name = "core-identity"

[services.variables]
PORT = "9000"
```

#### be-legal-case/railway.toml
```toml
[build]
builder = "nixpacks"

[deploy]
startCommand = "java -jar target/server.jar"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

[[services]]
name = "be-legal-case"

[services.variables]
PORT = "8083"
```

### 3. 数据库配置

Railway 提供托管的 PostgreSQL 和 Redis：

1. **添加 PostgreSQL 服务**
   - 在 Railway 项目中点击 "Add Service"
   - 选择 "PostgreSQL"
   - Railway 自动提供连接变量

2. **添加 Redis 服务**
   - 在 Railway 项目中点击 "Add Service"
   - 选择 "Redis"
   - Railway 自动提供连接变量

## 🔒 环境变量安全配置

### Railway Variables 最佳实践

1. **分类管理**:
   ```
   Database Variables:
   - POSTGRES_HOST
   - POSTGRES_PASSWORD
   - REDIS_PASSWORD
   
   API Keys:
   - OPENAI_API_KEY
   - GOOGLE_CLIENT_SECRET
   
   Service URLs:
   - CORE_IDENTITY_URI
   - AUTH_SERVER
   ```

2. **使用 Railway 的变量引用**:
   ```bash
   # 引用其他服务的 URL
   CORE_IDENTITY_URI=${{core-identity.RAILWAY_PUBLIC_DOMAIN}}
   AUTH_SERVER=https://${{core-identity.RAILWAY_PUBLIC_DOMAIN}}
   ```

## 🚀 部署流程

### 1. 准备代码
```bash
# 确保 .env 文件不被提交
git status
git add .gitignore
git commit -m "Add .gitignore for environment variables"
git push origin main
```

### 2. Railway 项目创建
```bash
# 安装 Railway CLI (可选)
npm install -g @railway/cli

# 登录 Railway
railway login

# 连接项目
railway link
```

### 3. 环境变量设置

在 Railway Dashboard 中：

1. 选择服务
2. 转到 "Variables" 标签
3. 添加所有必需的环境变量
4. 保存并触发重新部署

### 4. 部署验证

```bash
# 检查服务健康状态
curl https://your-service.railway.app/health

# 检查 API 文档
curl https://your-service.railway.app/api/service/swagger-ui.html
```

## 🔧 本地开发 vs Railway 配置对比

| 配置项 | 本地开发 | Railway 部署 |
|--------|----------|-------------|
| 数据库 | localhost:15432 | Railway PostgreSQL |
| Redis | localhost:16379 | Railway Redis |
| 服务域名 | 127.0.0.1:port | https://service.railway.app |
| SSL/TLS | HTTP | HTTPS (自动) |
| 环境变量 | .env 文件 | Railway Variables |
| 日志级别 | DEBUG | INFO |

## 📊 监控和日志

### Railway 内置监控

1. **实时日志**:
   - Railway Dashboard → Service → Logs
   - 实时查看应用日志

2. **资源监控**:
   - CPU 使用率
   - 内存使用量
   - 网络流量

3. **部署历史**:
   - 查看部署记录
   - 快速回滚到之前版本

### 应用监控配置

在 application.yaml 中启用监控端点：

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when-authorized
```

## 🚨 故障排查

### 常见问题

1. **服务启动失败**:
   - 检查 Railway Variables 是否配置正确
   - 查看 Railway 日志中的错误信息
   - 确认数据库连接字符串格式

2. **服务间通信失败**:
   - 确认服务 URL 配置正确
   - 检查 Railway 项目间的网络连接
   - 验证 OAuth2 配置

3. **环境变量未生效**:
   - 确认 EnvConfig 在 Railway 环境中正常工作
   - 检查变量名拼写
   - 重新部署服务

### Railway CLI 调试

```bash
# 查看服务状态
railway status

# 查看实时日志
railway logs

# 连接到服务进行调试
railway shell
```

## 💡 总结

- ✅ **本地开发**: 使用 `.env` 文件（不提交）
- ✅ **Railway 部署**: 使用 Railway Variables
- ✅ **代码兼容**: EnvConfig 同时支持两种方式
- ✅ **安全性**: 敏感信息只在 Railway Variables 中配置
- ✅ **可维护性**: `.env.example` 文件作为配置模板

这种方式既保证了开发效率，又确保了部署安全性和可维护性。