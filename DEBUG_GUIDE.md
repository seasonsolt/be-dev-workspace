# IDEA Debug 最佳实践指南

## 🎯 推荐方案：混合模式

### 基础设施：Docker Compose
```bash
# 启动数据库、Redis和Consul
make infra-start

# 访问Consul管理界面
make consul-ui  # 或直接访问 http://localhost:8500
```

### 业务服务：IDEA本地启动

## 🚀 快速启动步骤

### 1. 启动基础设施
```bash
# 方式1：使用Makefile
make infra-start

# 方式2：直接使用Docker Compose
docker-compose -f docker-compose.dev.yml up -d postgres redis
```

### 2. IDEA中启动服务
1. 打开IDEA，载入项目
2. 在Run/Debug Configurations中找到：
   - `Core Identity` - 身份认证服务 (端口9000)
   - `Legal Case Service` - 法律案例服务 (端口8083) 
   - `Core Workspace` - 工作空间服务 (端口8082)
   - `All Services Debug` - 一键启动所有服务

### 3. Debug模式启动
- 点击🐛图标以Debug模式启动
- 或使用快捷键 `Shift + F9`

## 🔧 各方案对比

| 方案 | Debug支持 | 热重载 | 启动速度 | 资源占用 | 复杂度 |
|------|-----------|---------|----------|----------|---------|
| **混合方案** ⭐ | ✅ 完美 | ✅ 支持 | ⚡ 快 | 💚 中等 | 🟢 简单 |
| IDEA纯本地 | ✅ 完美 | ✅ 支持 | ⚡ 最快 | 💚 最低 | 🟢 简单 |
| Docker Compose | ❌ 需要remote debug | ❌ 不支持 | 🐌 慢 | 🔴 最高 | 🔴 复杂 |
| Shell脚本 | ❌ 不支持 | ❌ 不支持 | 🐌 慢 | 💚 中等 | 🟡 中等 |

## 💡 Debug技巧

### 1. 设置断点
- 代码行号左侧点击设置断点
- 条件断点：右键断点 → More → Condition

### 2. 环境变量调试
- `.env`文件会被`EnvConfig`自动加载
- IDEA环境变量会覆盖`.env`中的值

### 3. 多服务联调
1. 先启动`Core Identity`（其他服务依赖它）
2. 再启动其他服务
3. 使用`All Services Debug`配置一键启动所有服务

### 4. 端口冲突处理
如果端口被占用：
```bash
# 查看端口占用
lsof -i :9000
lsof -i :8083

# 杀掉进程
kill -9 PID
```

## 📋 常用IDEA配置

### 1. 自动重启配置
在`application.yaml`中添加：
```yaml
spring:
  devtools:
    restart:
      enabled: true
    livereload:
      enabled: true
```

### 2. Debug JVM参数
```
-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5005
```

### 3. 内存调试参数
```
-Xms512m -Xmx1024m -XX:+HeapDumpOnOutOfMemoryError
```

## 🔄 工作流程

### 日常开发
1. `make infra-start` - 启动基础设施
2. IDEA中Debug启动需要的服务
3. 修改代码 → 自动热重载
4. 设断点调试

### 集成测试
1. `make start` - 启动完整环境
2. 运行集成测试
3. `make stop` - 清理环境

### 生产构建
```bash
make clean
make build
make test
```

## 🚨 常见问题

### Q: 服务启动失败
A: 检查端口是否被占用，确保基础设施已启动

### Q: 断点不生效
A: 确保以Debug模式启动，检查Source Code与运行代码一致

### Q: 环境变量不生效
A: 检查`.env`文件格式，确保`EnvConfig`正常工作

### Q: 服务间调用失败
A: 检查服务启动顺序，确保URL配置正确

## 🎉 推荐工作流

```bash
# 1. 启动基础设施
make infra-start

# 2. IDEA中Debug启动核心服务
# Core Identity → Legal Case Service

# 3. 开发过程中按需启动其他服务
# 4. 完成后清理
make stop
```

这种混合方案既保证了优秀的Debug体验，又避免了本地环境配置的复杂性。