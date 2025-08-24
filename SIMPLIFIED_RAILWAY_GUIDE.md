# 简化版 Railway 部署指南

如果您只在 Railway 上部署，不需要本地 `.env` 文件支持，可以使用这个简化方案。

## 🗑️ 要删除的文件

```bash
# 删除 EnvConfig 类
rm core-identity/src/main/java/com/ginkgooai/core/identity/config/EnvConfig.java
rm be-legal-case/src/main/java/com/ginkgooai/legalcase/config/EnvConfig.java
rm core-workspace/src/main/java/com/ginkgooai/core/workspace/config/EnvConfig.java

# 删除 dotenv 依赖（在 pom.xml 中移除）
# 删除本地 .env 文件和相关脚本
rm -f */.env
rm setup-env.sh
```

## 📝 简化后的 pom.xml

移除 dotenv 依赖：

```xml
<!-- 删除这个依赖块 -->
<!-- 
<dependency>
    <groupId>io.github.cdimascio</groupId>
    <artifactId>dotenv-java</artifactId>
    <version>3.0.0</version>
</dependency>
-->
```

## 🚀 部署方式

### Railway Variables 配置

在 Railway Dashboard → Variables 中配置：

```bash
# 基础配置
SERVER_PORT=9000
POSTGRES_HOST=railway-postgres-host
POSTGRES_PORT=5432
POSTGRES_DB=railway
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your-password

# 服务通信
AUTH_SERVER=https://your-identity.railway.app
CORE_WORKSPACE_URI=https://your-workspace.railway.app

# API 密钥
OPENAI_API_KEY=your-key
```

### application.yaml 保持不变

Spring Boot 原生支持环境变量：

```yaml
server:
  port: ${SERVER_PORT:9000}

spring:
  datasource:
    url: jdbc:postgresql://${POSTGRES_HOST:localhost}:${POSTGRES_PORT:5432}/${POSTGRES_DB:postgres}?currentSchema=${POSTGRES_SCHEMA:public}
    username: ${POSTGRES_USER:postgres}
    password: ${POSTGRES_PASSWORD:postgres}
```

## 📋 优缺点

### ✅ 优点
- 代码更简洁
- 没有额外依赖
- Railway 原生支持
- 部署更快

### ❌ 缺点
- 本地开发需要手动设置系统环境变量
- 团队协作时环境配置较复杂
- 无法使用 .env 文件的便利性

## 🔧 本地开发替代方案

### 方案1: IDE 环境变量配置

在 IntelliJ IDEA 中：
1. Run → Edit Configurations
2. Environment variables 中添加变量

### 方案2: 系统环境变量

```bash
# 在 ~/.bashrc 或 ~/.zshrc 中添加
export POSTGRES_HOST=localhost
export POSTGRES_PORT=15432
export POSTGRES_PASSWORD=postgres
export SERVER_PORT=9000

# 重新加载
source ~/.bashrc
```

### 方案3: Spring Profiles

使用不同的 application-{profile}.yaml：

```yaml
# application-local.yaml
server:
  port: 9000

spring:
  datasource:
    url: jdbc:postgresql://localhost:15432/postgres?currentSchema=identity
    username: postgres
    password: postgres
```

启动时指定 profile：
```bash
mvn spring-boot:run -Dspring.profiles.active=local
```