# 环境变量快速设置指南

## 🚀 快速开始

### 1. 本地开发环境设置

```bash
# 1. 克隆仓库后，设置环境变量
./setup-env.sh

# 2. 或者手动复制模板文件
cp core-identity/.env.example core-identity/.env
cp be-legal-case/.env.example be-legal-case/.env
cp core-workspace/.env.example core-workspace/.env

# 3. 编辑配置文件填入实际值
nano core-identity/.env
nano be-legal-case/.env
nano core-workspace/.env

# 4. 启动服务
cd core-identity && mvn spring-boot:run    # 端口 9000
cd be-legal-case && mvn spring-boot:run    # 端口 8083
cd core-workspace && mvn spring-boot:run   # 端口 8082
```

### 2. Railway 部署

Railway 不需要 `.env` 文件，在 Railway Variables 中配置环境变量。

详细配置请参考: [Railway 部署指南](RAILWAY_DEPLOYMENT_GUIDE.md)

## 📁 文件说明

| 文件 | 用途 | 是否提交 |
|------|------|----------|
| `.env` | 本地开发配置 | ❌ 不提交 |
| `.env.example` | 配置模板 | ✅ 提交 |
| `.gitignore` | Git 忽略规则 | ✅ 提交 |

## 🔑 必填配置项

编辑各服务的 `.env` 文件时，请务必填入：

- `POSTGRES_PASSWORD` - 数据库密码
- `OPENAI_API_KEY` - AI 服务密钥 (legal-case 服务需要)
- `MAIL_USERNAME` & `MAIL_PASSWORD` - 邮件服务配置 (identity 服务需要)

## 📚 详细文档

- [Spring Boot .env 使用指南](SPRING_BOOT_DOTENV_GUIDE.md)
- [Railway 部署配置指南](RAILWAY_DEPLOYMENT_GUIDE.md)
- [环境变量总体配置](ENVIRONMENT_CONFIGURATION.md)