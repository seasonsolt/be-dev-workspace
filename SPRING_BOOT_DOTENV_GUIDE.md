# Spring Boot .env 文件使用指南

本指南说明如何在 Ginkgoo AI 微服务项目中优雅地使用 `.env` 文件管理环境变量。

## 🚀 快速开始

### 1. 添加依赖

在每个 Spring Boot 服务的 `pom.xml` 中添加 dotenv-java 依赖：

```xml
<!-- Environment Variables (.env) Support -->
<dependency>
    <groupId>io.github.cdimascio</groupId>
    <artifactId>dotenv-java</artifactId>
    <version>3.0.0</version>
</dependency>
```

### 2. 创建 EnvConfig 配置类

在 `src/main/java/com/ginkgooai/[service]/config/` 目录下创建 `EnvConfig.java`：

```java
package com.ginkgooai.[service].config;

import io.github.cdimascio.dotenv.Dotenv;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;

/**
 * Configuration class to load .env file into Spring Environment
 */
@Slf4j
@Configuration
public class EnvConfig {

    private final ConfigurableEnvironment environment;

    public EnvConfig(ConfigurableEnvironment environment) {
        this.environment = environment;
    }

    @PostConstruct
    public void loadEnvFile() {
        try {
            Dotenv dotenv = Dotenv.configure()
                    .directory(".")  // Look for .env in project root
                    .ignoreIfMalformed()
                    .ignoreIfMissing()
                    .load();

            // Add .env properties to Spring Environment
            MapPropertySource envPropertySource = new MapPropertySource("dotenv", dotenv.entries());
            environment.getPropertySources().addFirst(envPropertySource);

            log.info("Successfully loaded .env file with {} properties", dotenv.entries().size());

        } catch (Exception e) {
            log.warn("Could not load .env file: {}", e.getMessage());
        }
    }
}
```

### 3. 在 application.yaml 中使用环境变量

```yaml
server:
  port: ${SERVICE_PORT:8080}

spring:
  datasource:
    url: jdbc:postgresql://${POSTGRES_HOST:localhost}:${POSTGRES_PORT:5432}/${POSTGRES_DB:postgres}?currentSchema=${POSTGRES_SCHEMA:public}
    username: ${POSTGRES_USER:postgres}
    password: ${POSTGRES_PASSWORD:postgres}
  
  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}
      password: ${REDIS_PASSWORD:}

# OAuth2 Configuration
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: ${AUTH_SERVER:http://localhost:9000}
          jwk-set-uri: ${OAUTH2_JWK_SET_URI:http://localhost:9000/.well-known/jwks.json}

# Service Discovery
core-workspace-uri: ${CORE_WORKSPACE_URI:http://127.0.0.1:8082}

# Logging
logging:
  level:
    root: ${LOGGING_LEVEL_ROOT:INFO}
    com.ginkgooai: ${LOGGING_LEVEL_GINKGOOAI:INFO}
```

## 📁 文件结构

```
your-service/
├── .env                    # 环境变量文件 (不要提交到git)
├── .env.example           # 环境变量模板 (可以提交)
├── src/main/java/com/ginkgooai/service/config/
│   └── EnvConfig.java     # .env加载配置
└── src/main/resources/
    └── application.yaml   # 使用${ENV_VAR:default}语法
```

## 🔧 环境变量命名规范

### 数据库配置
```bash
POSTGRES_HOST=localhost
POSTGRES_PORT=15432
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_SCHEMA=service_name
```

### Redis 配置
```bash
REDIS_HOST=localhost
REDIS_PORT=16379
REDIS_PASSWORD=
```

### 服务配置
```bash
SERVICE_PORT=8080
SERVICE_HOST=localhost
SERVICE_BASE_URL=http://localhost:8080
```

### OAuth2 配置
```bash
AUTH_SERVER=http://localhost:9000
OAUTH2_ISSUER_URL=http://localhost:9000
OAUTH2_JWK_SET_URI=http://localhost:9000/.well-known/jwks.json
```

### 服务间通信
```bash
CORE_IDENTITY_URI=http://localhost:9000
CORE_WORKSPACE_URI=http://127.0.0.1:8082
BE_LEGAL_CASE_URI=http://127.0.0.1:8083
```

## 🛡️ 安全最佳实践

### 1. .gitignore 配置
确保 `.env` 文件不被提交：

```gitignore
# Environment variables
.env
.env.local
.env.*.local

# But allow .env.example
!.env.example
```

### 2. 创建 .env.example
创建环境变量模板供其他开发者参考：

```bash
# Database Configuration
POSTGRES_HOST=localhost
POSTGRES_PORT=15432
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_password_here
POSTGRES_SCHEMA=service_schema

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=16379
REDIS_PASSWORD=

# Service Configuration
SERVICE_PORT=8080
SERVICE_HOST=localhost

# Add your other environment variables here...
```

### 3. 敏感信息处理
- ❌ 不要在 `.env` 文件中存储生产环境密钥
- ✅ 生产环境使用密钥管理服务 (如 AWS Secrets Manager, Azure Key Vault)
- ✅ 使用默认值处理可选配置

## 🚀 启动和部署

### 开发环境启动
```bash
# 1. 复制环境变量模板
cp .env.example .env

# 2. 编辑 .env 文件填入实际值
nano .env

# 3. 启动服务
mvn spring-boot:run
```

### Docker 部署
```dockerfile
# Dockerfile 示例
FROM openjdk:23-jdk
COPY target/app.jar app.jar

# .env 文件在运行时通过 volume 挂载
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

```yaml
# docker-compose.yml 示例
version: '3.8'
services:
  your-service:
    build: .
    ports:
      - "8080:8080"
    volumes:
      - ./.env:/app/.env  # 挂载 .env 文件
    environment:
      - SPRING_PROFILES_ACTIVE=production
```

### 生产环境
生产环境建议使用系统环境变量而不是 `.env` 文件：

```bash
# 通过环境变量启动
export POSTGRES_PASSWORD=secure_password
export REDIS_PASSWORD=secure_redis_password
java -jar app.jar
```

## 📊 验证配置

### 1. 启动日志检查
启动时会看到类似日志：
```
INFO - Successfully loaded .env file with 15 properties
```

### 2. Actuator 端点检查
```bash
# 检查配置属性 (注意: 生产环境不要暴露敏感信息)
curl http://localhost:8080/actuator/env
```

### 3. 应用健康检查
```bash
curl http://localhost:8080/actuator/health
```

## ⚠️ 常见问题

### 问题 1: .env 文件未加载
**现象**: 环境变量为空或使用默认值

**解决方案**:
1. 确认 `.env` 文件位于项目根目录
2. 检查文件权限
3. 确认 `EnvConfig` 类在 Spring 组件扫描范围内

### 问题 2: 变量值包含特殊字符
**现象**: 配置解析错误

**解决方案**:
```bash
# 使用引号包围包含特殊字符的值
DATABASE_URL="postgres://user:pass@localhost:5432/db?sslmode=require"
SECRET_KEY="key_with_special_chars!@#$%"
```

### 问题 3: 不同环境使用不同配置
**解决方案**: 使用多个 .env 文件
```java
// EnvConfig.java 中支持多环境
String profile = System.getProperty("spring.profiles.active", "dev");
Dotenv dotenv = Dotenv.configure()
    .filename(".env." + profile)  // .env.dev, .env.prod
    .ignoreIfMissing()
    .load();
```

## 🎯 总结

使用 dotenv-java 库可以让 Spring Boot 项目优雅地管理环境变量：

1. ✅ **开发友好**: 本地开发使用 `.env` 文件
2. ✅ **生产安全**: 生产环境使用系统环境变量
3. ✅ **配置统一**: 所有环境变量在一个地方管理
4. ✅ **版本控制**: `.env.example` 模板可以版本控制
5. ✅ **Spring 集成**: 与 Spring Boot 原生配置完美集成

这种方式既保持了开发环境的便利性，又确保了生产环境的安全性。