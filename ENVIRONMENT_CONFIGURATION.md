# Ginkgoo AI 微服务环境变量统一配置

## 总体架构配置

根据系统架构要求，各微服务的环境变量已统一配置：

### 主机地址分配
- **core-identity**: 使用 `localhost` (作为OAuth2认证服务器)
- **其他所有服务**: 使用 `127.0.0.1`

### 统一端口分配
- **PostgreSQL**: 15432 (用户名/密码: postgres/postgres)
- **Redis**: 16379
- **core-gateway**: 8080
- **core-identity**: 9000  
- **core-workspace**: 8082
- **be-legal-case**: 8083
- **be-core-storage**: 8084
- **be-core-messaging**: 8085
- **be-core-intelligence**: 8000 (Python/FastAPI)

## 各服务环境变量文件

所有服务都创建了对应的 `.env` 文件，位置如下：

### Java 微服务
```
/Users/Thin/Source/git/ginkgoo-ai/core-identity/.env
/Users/Thin/Source/git/ginkgoo-ai/core-workspace/.env  
/Users/Thin/Source/git/ginkgoo-ai/be-legal-case/.env
/Users/Thin/Source/git/ginkgoo-ai/core-gateway/.env
/Users/Thin/Source/git/ginkgoo-ai/be-core-storage/.env
/Users/Thin/Source/git/ginkgoo-ai/be-core-messaging/.env
```

### Python 微服务
```
/Users/Thin/Source/git/ginkgoo-ai/be-core-intelligence/.env
```

## 数据库Schema分离

每个服务使用独立的PostgreSQL schema：
- `identity` - core-identity
- `workspace` - core-workspace  
- `legalcase` - be-legal-case
- `gateway` - core-gateway (如需要)
- `storage` - be-core-storage
- `messaging` - be-core-messaging
- `intelligence` - be-core-intelligence

## 服务间通信配置

### OAuth2/JWT 认证流程
- **认证服务器**: core-identity (localhost:9000)
- **资源服务器**: 其他所有服务从 core-identity 验证JWT令牌
- **JWK Set URI**: http://localhost:9000/.well-known/jwks.json

### 服务依赖关系
```
core-identity (localhost:9000) 
    ↓ JWT认证
core-workspace (127.0.0.1:8082)
    ↓ 工作空间权限
be-legal-case (127.0.0.1:8083)
    ↓ 业务调用
be-core-storage (127.0.0.1:8084)
be-core-messaging (127.0.0.1:8085)  
be-core-intelligence (127.0.0.1:8000)
```

## 启动顺序建议

1. **基础设施**
   ```bash
   # PostgreSQL (端口 15432)
   # Redis (端口 16379)
   ```

2. **核心服务** (按依赖关系)
   ```bash
   cd core-identity && mvn spring-boot:run          # 9000
   cd core-workspace && mvn spring-boot:run        # 8082  
   cd core-gateway && mvn spring-boot:run          # 8080 (可选)
   ```

3. **业务服务**
   ```bash
   cd be-legal-case && mvn spring-boot:run         # 8083
   cd be-core-storage && mvn spring-boot:run       # 8084
   cd be-core-messaging && mvn spring-boot:run     # 8085
   cd be-core-intelligence && python main.py       # 8000
   ```

## 环境变量说明

### 必需配置的变量
- **AI服务**: `OPENAI_API_KEY`, `OPENROUTER_API_KEY`
- **邮件服务**: `SENDGRID_API_KEY` 或 SMTP配置
- **云存储**: R2/S3 相关配置 (storage服务)

### 可选配置的变量
- **GitHub认证**: `GITHUB_USER`, `GITHUB_TOKEN` (用于私有仓库依赖)
- **监控**: OpenTelemetry相关配置
- **日志级别**: 默认INFO，开发时可设置DEBUG

## 开发环境配置验证

启动各服务后可通过以下端点验证配置：

```bash
# 健康检查
curl http://localhost:9000/health      # core-identity
curl http://127.0.0.1:8082/health      # core-workspace  
curl http://127.0.0.1:8083/health      # be-legal-case
curl http://127.0.0.1:8084/health      # be-core-storage
curl http://127.0.0.1:8085/health      # be-core-messaging
curl http://127.0.0.1:8000/health      # be-core-intelligence
```

```bash
# API文档
http://localhost:9000/api/identity/swagger-ui.html
http://127.0.0.1:8082/api/workspace/swagger-ui.html  
http://127.0.0.1:8083/api/legalcase/swagger-ui.html
http://127.0.0.1:8084/api/storage/swagger-ui.html
http://127.0.0.1:8085/api/messaging/swagger-ui.html
http://127.0.0.1:8000/docs
```

## 故障排查

### 常见问题
1. **端口冲突**: 确保各服务端口不冲突
2. **数据库连接**: 确认PostgreSQL运行在15432端口
3. **Redis连接**: 确认Redis运行在16379端口  
4. **JWT验证失败**: 确认core-identity服务正常运行
5. **跨服务调用失败**: 检查服务间URL配置是否正确

### 日志位置
各服务日志默认输出到控制台，生产环境可配置到文件：
- Java服务: 使用logback配置
- Python服务: 使用Python logging模块

## 生产环境注意事项

1. **安全配置**: 生产环境需要配置HTTPS和适当的CORS策略
2. **数据库**: 建议使用连接池和读写分离
3. **缓存**: Redis建议配置持久化和集群
4. **监控**: 配置APM和日志聚合
5. **密钥管理**: 使用密钥管理服务而非环境变量存储敏感信息