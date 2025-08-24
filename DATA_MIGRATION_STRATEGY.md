# 多租户数据迁移策略

## 概述

本文档详述了将现有无租户数据迁移到默认workspace的完整策略，确保数据完整性和业务连续性。

## 迁移范围分析

### 需要迁移的服务和数据

#### 1. core-identity服务
**Schema**: `identity`
**无租户表**:
- `user_info` - 用户基础信息
- `oauth2_registered_client` - OAuth客户端注册
- `user_social_connections` - 社交登录连接
- `mfa_info` - 多因素认证信息

**迁移策略**: 这些是全局数据，不需要workspace隔离

#### 2. core-workspace服务
**Schema**: `workspace`
**迁移表**:
- `workspaces` - 工作区（需要创建默认workspace）
- `workspace_members` - 成员关系（需要将所有用户加入默认workspace）
- `workspace_invitations` - 邀请记录（已有workspace_id，检查完整性）

#### 3. be-legal-case服务
**Schema**: `legalcase`
**需要迁移的表**:
- `legal_cases` ✅
- `case_documents` ✅  
- `profiles` ✅
- `conversation_messages` ✅
- `legal_rules` ✅
- `legal_validation_results` ✅
- `prompt_templates` ✅
- `prompt_executions` ✅
- `profile_schemas` ✅

#### 4. be-core-storage服务
**Schema**: `storage`
**需要迁移的表**:
- `cloud_files` - 云文件记录
- `video_metadata` - 视频元数据

#### 5. be-core-messaging服务
**Schema**: `messaging`  
**需要迁移的表**:
- `emails` - 邮件记录
- `email_templates` - 邮件模板

## 迁移执行计划

### Phase 1: 准备阶段

#### 1.1 创建默认Workspace
```sql
-- 在workspace schema中创建默认workspace
INSERT INTO workspace.workspaces (
    id,
    name, 
    domain,
    description,
    status,
    created_at,
    updated_at,
    created_by,
    updated_by
) VALUES (
    'default-workspace-uuid',
    'Default Workspace',
    'default.ginkgoo.ai', 
    'System default workspace for existing data migration',
    'ACTIVE',
    NOW(),
    NOW(),
    'system-migration',
    'system-migration'
);
```

#### 1.2 将所有现有用户加入默认Workspace
```sql
-- 为每个现有用户创建workspace成员记录
INSERT INTO workspace.workspace_members (
    id,
    workspace_id,
    user_id, 
    role,
    joined_at,
    created_at,
    updated_at,
    created_by,
    updated_by
)
SELECT 
    CONCAT('member-', ui.id),
    'default-workspace-uuid',
    ui.id,
    'ADMIN', -- 将现有用户设为管理员
    NOW(),
    NOW(), 
    NOW(),
    'system-migration',
    'system-migration'
FROM identity.user_info ui
WHERE NOT EXISTS (
    SELECT 1 FROM workspace.workspace_members wm 
    WHERE wm.user_id = ui.id AND wm.workspace_id = 'default-workspace-uuid'
);
```

### Phase 2: 数据迁移执行

#### 2.1 Legal Case Service迁移
```sql
-- 迁移legal_cases表
UPDATE legalcase.legal_cases 
SET workspace_id = 'default-workspace-uuid'
WHERE workspace_id IS NULL;

-- 迁移case_documents表  
UPDATE legalcase.case_documents
SET workspace_id = 'default-workspace-uuid' 
WHERE workspace_id IS NULL;

-- 迁移profiles表
UPDATE legalcase.profiles
SET workspace_id = 'default-workspace-uuid'
WHERE workspace_id IS NULL;

-- 迁移conversation_messages表
UPDATE legalcase.conversation_messages
SET workspace_id = 'default-workspace-uuid'
WHERE workspace_id IS NULL;

-- 迁移legal_rules表
UPDATE legalcase.legal_rules  
SET workspace_id = 'default-workspace-uuid'
WHERE workspace_id IS NULL;

-- 迁移legal_validation_results表
UPDATE legalcase.legal_validation_results
SET workspace_id = 'default-workspace-uuid'
WHERE workspace_id IS NULL;

-- 迁移prompt_templates表
UPDATE legalcase.prompt_templates
SET workspace_id = 'default-workspace-uuid'  
WHERE workspace_id IS NULL;

-- 迁移prompt_executions表
UPDATE legalcase.prompt_executions
SET workspace_id = 'default-workspace-uuid'
WHERE workspace_id IS NULL;

-- 迁移profile_schemas表
UPDATE legalcase.profile_schemas
SET workspace_id = 'default-workspace-uuid'
WHERE workspace_id IS NULL;
```

#### 2.2 Storage Service迁移
```sql
-- 迁移cloud_files表
UPDATE storage.cloud_files
SET workspace_id = 'default-workspace-uuid'
WHERE workspace_id IS NULL;

-- 迁移video_metadata表  
UPDATE storage.video_metadata
SET workspace_id = 'default-workspace-uuid'
WHERE workspace_id IS NULL;
```

#### 2.3 Messaging Service迁移
```sql
-- 迁移emails表
UPDATE messaging.emails
SET workspace_id = 'default-workspace-uuid'
WHERE workspace_id IS NULL;

-- 迁移email_templates表
UPDATE messaging.email_templates  
SET workspace_id = 'default-workspace-uuid'
WHERE workspace_id IS NULL;
```

### Phase 3: 数据完整性验证

#### 3.1 迁移统计验证
```sql
-- 验证Legal Case Service迁移结果
SELECT 
    'legal_cases' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN workspace_id IS NULL THEN 1 END) as null_workspace_count,
    COUNT(CASE WHEN workspace_id = 'default-workspace-uuid' THEN 1 END) as default_workspace_count
FROM legalcase.legal_cases

UNION ALL

SELECT 
    'case_documents' as table_name,
    COUNT(*) as total_records, 
    COUNT(CASE WHEN workspace_id IS NULL THEN 1 END) as null_workspace_count,
    COUNT(CASE WHEN workspace_id = 'default-workspace-uuid' THEN 1 END) as default_workspace_count
FROM legalcase.case_documents

-- ... 对所有表执行类似验证
```

#### 3.2 关联数据完整性检查
```sql
-- 检查legal_cases和case_documents的关联完整性
SELECT 
    lc.id as case_id,
    lc.workspace_id as case_workspace,
    COUNT(cd.id) as document_count,
    COUNT(CASE WHEN cd.workspace_id != lc.workspace_id THEN 1 END) as workspace_mismatch_count
FROM legalcase.legal_cases lc
LEFT JOIN legalcase.case_documents cd ON lc.id = cd.case_id
GROUP BY lc.id, lc.workspace_id
HAVING COUNT(CASE WHEN cd.workspace_id != lc.workspace_id THEN 1 END) > 0;
```

## 回滚策略

### 自动回滚脚本
```sql
-- 如果迁移失败，回滚到原始状态
BEGIN;

-- 记录回滚操作
CREATE TABLE IF NOT EXISTS migration_rollback_log (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(100),
    record_count INTEGER,
    rollback_timestamp TIMESTAMP DEFAULT NOW()
);

-- 回滚legal_cases
UPDATE legalcase.legal_cases 
SET workspace_id = NULL 
WHERE workspace_id = 'default-workspace-uuid';

INSERT INTO migration_rollback_log (table_name, record_count) 
VALUES ('legal_cases', ROW_COUNT());

-- 继续回滚其他表...

COMMIT;
```

### 备份策略
```bash
# 迁移前完整备份
pg_dump -h localhost -U postgres -d ginkgoo_db > pre_migration_backup.sql

# 按schema分别备份
pg_dump -h localhost -U postgres -d ginkgoo_db -n legalcase > legalcase_backup.sql
pg_dump -h localhost -U postgres -d ginkgoo_db -n workspace > workspace_backup.sql
pg_dump -h localhost -U postgres -d ginkgoo_db -n storage > storage_backup.sql
pg_dump -h localhost -U postgres -d ginkgoo_db -n messaging > messaging_backup.sql
```

## 迁移脚本实现

### 主迁移脚本
```bash
#!/bin/bash
# migrate_to_default_workspace.sh

set -e

DB_HOST=${POSTGRES_HOST:-localhost}
DB_PORT=${POSTGRES_PORT:-15432}
DB_NAME=${POSTGRES_DB:-postgres}
DB_USER=${POSTGRES_USER:-postgres}
DB_PASSWORD=${POSTGRES_PASSWORD}

DEFAULT_WORKSPACE_ID="default-workspace-$(uuidgen)"

echo "Starting multi-tenant data migration..."
echo "Default Workspace ID: $DEFAULT_WORKSPACE_ID"

# 执行迁移SQL
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f migration.sql -v default_workspace_id=$DEFAULT_WORKSPACE_ID

echo "Migration completed successfully!"
```

## 风险控制

### 迁移前检查清单
- [ ] 数据库备份完成
- [ ] 应用服务暂停（可选，用于零停机迁移）
- [ ] 迁移脚本在测试环境验证通过
- [ ] 回滚脚本准备就绪
- [ ] 监控系统就绪

### 监控指标
- 迁移进度（已处理记录数/总记录数）
- 数据完整性指标
- 迁移耗时统计
- 错误和异常统计

### 性能考虑
- 批量更新减少锁定时间
- 在非高峰期执行迁移
- 监控数据库性能指标
- 必要时使用分批迁移策略

## 迁移验证

### 业务功能验证
1. **用户登录**: 验证用户可以正常登录并访问默认workspace
2. **案例管理**: 验证现有案例数据可以正常访问和操作
3. **文档管理**: 验证文档上传、下载和管理功能正常
4. **权限系统**: 验证用户在默认workspace中的权限正确

### 数据一致性验证
1. **记录数量**: 迁移前后各表记录数量一致
2. **关联完整性**: 外键关联关系保持完整
3. **数据内容**: 抽样检查数据内容未被破坏

## 后迁移任务

### 1. 清理工作
- 移除临时迁移表和数据
- 清理迁移日志（保留必要的审计记录）
- 更新应用配置

### 2. 监控设置
- 设置多租户相关监控指标
- 配置跨租户访问告警
- 建立数据隔离监控

### 3. 文档更新
- 更新API文档
- 更新运维手册
- 更新故障排查指南

## 应急预案

### 迁移失败处理
1. **立即停止迁移**
2. **执行回滚脚本**
3. **恢复应用服务**
4. **通知相关团队**
5. **分析失败原因**

### 生产环境特殊考虑
- 使用只读模式减少数据变更
- 准备快速回滚机制
- 建立迁移状态实时监控
- 准备紧急联系流程