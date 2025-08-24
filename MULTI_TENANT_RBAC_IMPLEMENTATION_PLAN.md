# 多租户RBAC实施计划

## 现状分析

### ✅ 已完成的部分

#### be-legal-case服务（当前分支继续）
- ✅ 多租户基础架构（BaseMultiTenantEntity, MultiTenantContextHolder）
- ✅ 数据库多租户支持（workspace_id字段）
- ✅ 请求拦截和上下文管理
- ✅ 基础权限验证框架

#### core-workspace服务（当前分支继续）  
- ✅ Workspace基础管理
- ✅ WorkspaceRole角色系统
- ✅ WorkspaceMember成员管理
- ✅ 权限层级控制

### ❌ 需要完善的部分

1. **权限系统增强** - 从角色扩展到细粒度权限
2. **JWT Token增强** - 包含workspace权限claims
3. **其他服务多租户支持** - core-identity, core-gateway, be-core-storage, be-core-messaging
4. **数据迁移** - 现有数据迁移到默认租户

## 分支策略

### 1. core-identity服务
```bash
# 创建feature分支
git checkout -b feature/multi-tenant-jwt-enhancement

# 实现内容：
# - JWT Token Customizer增强
# - 与workspace服务集成
# - 用户workspace权限查询API
```

### 2. core-gateway服务
```bash
# 创建feature分支  
git checkout -b feature/multi-tenant-bff-support

# 实现内容：
# - BFF模式下的workspace上下文传递
# - 请求路由的租户感知
# - API聚合的多租户支持
```

### 3. be-core-storage服务
```bash
# 创建feature分支
git checkout -b feature/multi-tenant-file-storage

# 实现内容：
# - 文件存储的workspace隔离
# - 云存储路径的租户前缀
# - 文件访问权限的workspace验证
```

### 4. be-core-messaging服务
```bash
# 创建feature分支
git checkout -b feature/multi-tenant-messaging

# 实现内容：
# - 邮件模板的workspace隔离
# - 发送记录的租户归属
# - 消息队列的多租户支持
```

## 实施优先级

### Phase 1: 核心权限系统完善（1-2周）
**当前分支继续开发**

#### 1.1 workspace服务RBAC增强
- [ ] 创建Permission实体和管理
- [ ] 实现RoleTemplate系统
- [ ] 增强WorkspaceRole支持自定义权限
- [ ] 实现权限缓存机制

#### 1.2 legal-case服务权限集成
- [ ] 集成新的权限验证组件
- [ ] 实现资源级权限检查
- [ ] 完善API权限注解

### Phase 2: JWT Token增强（1周）
**core-identity服务新分支**

#### 2.1 JWT Claims增强
- [ ] 实现EnhancedJwtTokenCustomizer
- [ ] 与workspace服务集成获取用户权限
- [ ] 添加workspace权限信息到JWT

#### 2.2 测试和验证
- [ ] JWT token格式验证
- [ ] 跨服务token验证测试

### Phase 3: 其他服务多租户支持（2-3周）
**各服务独立分支并行开发**

#### 3.1 core-gateway服务（优先）
- [ ] BFF模式workspace上下文
- [ ] 请求路由租户感知
- [ ] API聚合多租户支持

#### 3.2 be-core-storage服务
- [ ] 文件存储workspace隔离
- [ ] 云存储路径租户前缀
- [ ] 访问权限workspace验证

#### 3.3 be-core-messaging服务
- [ ] 邮件模板workspace隔离
- [ ] 发送记录租户归属
- [ ] 消息队列多租户支持

### Phase 4: 数据迁移和集成测试（1周）

#### 4.1 数据迁移
- [ ] 创建默认workspace
- [ ] 现有数据迁移脚本
- [ ] 数据完整性验证

#### 4.2 集成测试
- [ ] 端到端权限测试
- [ ] 性能测试
- [ ] 安全测试

## 数据迁移策略

### 默认租户设计
```sql
-- 创建默认workspace
INSERT INTO workspaces (
    id, 
    name, 
    domain, 
    status, 
    created_at, 
    updated_at
) VALUES (
    'default-workspace-uuid', 
    'Default Workspace', 
    'default.ginkgoo.ai', 
    'ACTIVE', 
    NOW(), 
    NOW()
);
```

### 数据迁移脚本
1. **识别无租户数据**：workspace_id为NULL的记录
2. **批量更新**：将所有无租户数据分配给默认workspace
3. **完整性检查**：验证所有核心表的workspace_id字段

### 迁移验证
- 迁移前数据统计
- 迁移后完整性检查
- 业务功能验证测试

## 技术实现要点

### 1. JWT Token结构
```json
{
  "sub": "user-id",
  "workspaces": {
    "workspace-id": {
      "name": "Law Firm A",
      "roles": ["SENIOR_LAWYER"],
      "permissions": ["case:*", "document:read"]
    }
  },
  "active_workspace": "workspace-id"
}
```

### 2. 权限验证模式
```java
@PreAuthorize("@workspaceSecurity.hasPermission('case:create')")
public LegalCase createCase(CreateCaseRequest request) {
    // 业务逻辑
}
```

### 3. 跨服务权限传递
- HTTP Header: `X-Workspace-ID`
- JWT Token中的workspace claims
- 服务间调用的上下文传递

## 测试策略

### 单元测试
- 权限验证组件测试
- 多租户上下文管理测试
- JWT token生成和解析测试

### 集成测试
- 跨服务权限验证
- 端到端业务流程测试
- 数据隔离验证

### 性能测试
- 多租户查询性能
- JWT token大小和解析性能
- 缓存命中率测试

## 风险控制

### 数据安全
- 严格的租户数据隔离
- 跨租户访问监控和告警
- 审计日志完整记录

### 系统稳定性
- 渐进式发布策略
- 回滚预案准备
- 监控指标完善

### 性能影响
- 数据库查询优化
- 缓存策略优化
- 批量操作优化

## 发布计划

### Week 1-2: 核心权限系统
- workspace服务权限模型完善
- legal-case服务权限集成

### Week 3: JWT增强
- core-identity服务JWT customizer
- 权限信息集成测试

### Week 4-6: 其他服务支持
- 各服务并行开发多租户支持
- 集成测试和验证

### Week 7: 部署和验证
- 数据迁移执行
- 生产环境验证
- 性能监控

## 成功标准

1. **功能完整性**：所有服务支持完整的多租户RBAC
2. **数据安全**：100%的租户数据隔离
3. **性能要求**：多租户查询性能不超过原有20%开销
4. **向后兼容**：现有API完全兼容
5. **安全合规**：通过安全审计和权限验证测试