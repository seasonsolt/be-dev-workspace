-- 多租户数据迁移脚本
-- 将现有无租户数据迁移到默认workspace
-- 执行方式: psql -f migrate_to_default_workspace.sql -v default_workspace_id='your-uuid-here'

\set ON_ERROR_STOP on

-- 设置默认workspace ID（如果没有提供变量）
\set default_workspace_id 'default-workspace-' :default_workspace_id

BEGIN;

-- 创建迁移日志表
CREATE TABLE IF NOT EXISTS migration_log (
    id SERIAL PRIMARY KEY,
    operation VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    affected_rows INTEGER,
    execution_timestamp TIMESTAMP DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'SUCCESS',
    error_message TEXT
);

-- 记录迁移开始
INSERT INTO migration_log (operation) VALUES ('MIGRATION_START');

-- =============================================================================
-- Phase 1: 创建默认Workspace（如果不存在）
-- =============================================================================

-- 检查默认workspace是否已存在
DO $$
DECLARE
    workspace_exists INTEGER;
BEGIN
    SELECT COUNT(*) INTO workspace_exists 
    FROM workspace.workspaces 
    WHERE id = :'default_workspace_id';
    
    IF workspace_exists = 0 THEN
        -- 创建默认workspace
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
            :'default_workspace_id',
            'Default Workspace',
            'default.ginkgoo.ai', 
            'System default workspace for existing data migration',
            'ACTIVE',
            NOW(),
            NOW(),
            'system-migration',
            'system-migration'
        );
        
        INSERT INTO migration_log (operation, table_name, affected_rows) 
        VALUES ('CREATE_DEFAULT_WORKSPACE', 'workspaces', 1);
        
        RAISE NOTICE 'Created default workspace: %', :'default_workspace_id';
    ELSE
        INSERT INTO migration_log (operation, table_name, affected_rows) 
        VALUES ('DEFAULT_WORKSPACE_EXISTS', 'workspaces', 0);
        
        RAISE NOTICE 'Default workspace already exists: %', :'default_workspace_id';
    END IF;
END $$;

-- =============================================================================
-- Phase 2: 将现有用户加入默认Workspace
-- =============================================================================

-- 为每个现有用户创建workspace成员记录
WITH new_members AS (
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
        'member-' || ui.id,
        :'default_workspace_id',
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
        WHERE wm.user_id = ui.id AND wm.workspace_id = :'default_workspace_id'
    )
    RETURNING id
)
INSERT INTO migration_log (operation, table_name, affected_rows)
VALUES ('ADD_USERS_TO_DEFAULT_WORKSPACE', 'workspace_members', (SELECT COUNT(*) FROM new_members));

-- =============================================================================
-- Phase 3: Legal Case Service数据迁移
-- =============================================================================

-- 迁移legal_cases表
WITH updated_cases AS (
    UPDATE legalcase.legal_cases 
    SET workspace_id = :'default_workspace_id'
    WHERE workspace_id IS NULL
    RETURNING id
)
INSERT INTO migration_log (operation, table_name, affected_rows)
VALUES ('MIGRATE_LEGAL_CASES', 'legal_cases', (SELECT COUNT(*) FROM updated_cases));

-- 迁移case_documents表  
WITH updated_documents AS (
    UPDATE legalcase.case_documents
    SET workspace_id = :'default_workspace_id' 
    WHERE workspace_id IS NULL
    RETURNING id
)
INSERT INTO migration_log (operation, table_name, affected_rows)
VALUES ('MIGRATE_CASE_DOCUMENTS', 'case_documents', (SELECT COUNT(*) FROM updated_documents));

-- 迁移profiles表
WITH updated_profiles AS (
    UPDATE legalcase.profiles
    SET workspace_id = :'default_workspace_id'
    WHERE workspace_id IS NULL
    RETURNING id
)
INSERT INTO migration_log (operation, table_name, affected_rows)
VALUES ('MIGRATE_PROFILES', 'profiles', (SELECT COUNT(*) FROM updated_profiles));

-- 迁移conversation_messages表
WITH updated_messages AS (
    UPDATE legalcase.conversation_messages
    SET workspace_id = :'default_workspace_id'
    WHERE workspace_id IS NULL
    RETURNING id
)
INSERT INTO migration_log (operation, table_name, affected_rows)
VALUES ('MIGRATE_CONVERSATION_MESSAGES', 'conversation_messages', (SELECT COUNT(*) FROM updated_messages));

-- 迁移legal_rules表
WITH updated_rules AS (
    UPDATE legalcase.legal_rules  
    SET workspace_id = :'default_workspace_id'
    WHERE workspace_id IS NULL
    RETURNING id
)
INSERT INTO migration_log (operation, table_name, affected_rows)
VALUES ('MIGRATE_LEGAL_RULES', 'legal_rules', (SELECT COUNT(*) FROM updated_rules));

-- 迁移legal_validation_results表
WITH updated_validations AS (
    UPDATE legalcase.legal_validation_results
    SET workspace_id = :'default_workspace_id'
    WHERE workspace_id IS NULL
    RETURNING id
)
INSERT INTO migration_log (operation, table_name, affected_rows)
VALUES ('MIGRATE_LEGAL_VALIDATION_RESULTS', 'legal_validation_results', (SELECT COUNT(*) FROM updated_validations));

-- 迁移prompt_templates表
WITH updated_templates AS (
    UPDATE legalcase.prompt_templates
    SET workspace_id = :'default_workspace_id'  
    WHERE workspace_id IS NULL
    RETURNING id
)
INSERT INTO migration_log (operation, table_name, affected_rows)
VALUES ('MIGRATE_PROMPT_TEMPLATES', 'prompt_templates', (SELECT COUNT(*) FROM updated_templates));

-- 迁移prompt_executions表
WITH updated_executions AS (
    UPDATE legalcase.prompt_executions
    SET workspace_id = :'default_workspace_id'
    WHERE workspace_id IS NULL
    RETURNING id
)
INSERT INTO migration_log (operation, table_name, affected_rows)
VALUES ('MIGRATE_PROMPT_EXECUTIONS', 'prompt_executions', (SELECT COUNT(*) FROM updated_executions));

-- 迁移profile_schemas表
WITH updated_schemas AS (
    UPDATE legalcase.profile_schemas
    SET workspace_id = :'default_workspace_id'
    WHERE workspace_id IS NULL
    RETURNING id
)
INSERT INTO migration_log (operation, table_name, affected_rows)
VALUES ('MIGRATE_PROFILE_SCHEMAS', 'profile_schemas', (SELECT COUNT(*) FROM updated_schemas));

-- =============================================================================
-- Phase 4: Storage Service数据迁移
-- =============================================================================

-- 迁移cloud_files表
WITH updated_files AS (
    UPDATE storage.cloud_files
    SET workspace_id = :'default_workspace_id'
    WHERE workspace_id IS NULL
    RETURNING id
)
INSERT INTO migration_log (operation, table_name, affected_rows)
VALUES ('MIGRATE_CLOUD_FILES', 'cloud_files', (SELECT COUNT(*) FROM updated_files));

-- 迁移video_metadata表（如果存在）
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'storage' AND table_name = 'video_metadata') THEN
        WITH updated_metadata AS (
            UPDATE storage.video_metadata
            SET workspace_id = :'default_workspace_id'
            WHERE workspace_id IS NULL
            RETURNING id
        )
        INSERT INTO migration_log (operation, table_name, affected_rows)
        VALUES ('MIGRATE_VIDEO_METADATA', 'video_metadata', (SELECT COUNT(*) FROM updated_metadata));
    ELSE
        INSERT INTO migration_log (operation, table_name, affected_rows)
        VALUES ('SKIP_VIDEO_METADATA', 'video_metadata', 0);
    END IF;
END $$;

-- =============================================================================
-- Phase 5: Messaging Service数据迁移
-- =============================================================================

-- 迁移emails表
WITH updated_emails AS (
    UPDATE messaging.emails
    SET workspace_id = :'default_workspace_id'
    WHERE workspace_id IS NULL
    RETURNING id
)
INSERT INTO migration_log (operation, table_name, affected_rows)
VALUES ('MIGRATE_EMAILS', 'emails', (SELECT COUNT(*) FROM updated_emails));

-- 迁移email_templates表  
WITH updated_email_templates AS (
    UPDATE messaging.email_templates  
    SET workspace_id = :'default_workspace_id'
    WHERE workspace_id IS NULL
    RETURNING id
)
INSERT INTO migration_log (operation, table_name, affected_rows)
VALUES ('MIGRATE_EMAIL_TEMPLATES', 'email_templates', (SELECT COUNT(*) FROM updated_email_templates));

-- =============================================================================
-- Phase 6: 数据完整性验证
-- =============================================================================

-- 创建验证结果表
CREATE TEMP TABLE validation_results (
    table_name VARCHAR(100),
    total_records INTEGER,
    null_workspace_count INTEGER,
    default_workspace_count INTEGER,
    validation_status VARCHAR(20)
);

-- 验证Legal Case Service迁移结果
INSERT INTO validation_results (table_name, total_records, null_workspace_count, default_workspace_count)
SELECT 
    'legal_cases',
    COUNT(*),
    COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
    COUNT(CASE WHEN workspace_id = :'default_workspace_id' THEN 1 END)
FROM legalcase.legal_cases;

INSERT INTO validation_results (table_name, total_records, null_workspace_count, default_workspace_count)
SELECT 
    'case_documents',
    COUNT(*),
    COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
    COUNT(CASE WHEN workspace_id = :'default_workspace_id' THEN 1 END)
FROM legalcase.case_documents;

INSERT INTO validation_results (table_name, total_records, null_workspace_count, default_workspace_count)
SELECT 
    'profiles',
    COUNT(*),
    COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
    COUNT(CASE WHEN workspace_id = :'default_workspace_id' THEN 1 END)
FROM legalcase.profiles;

INSERT INTO validation_results (table_name, total_records, null_workspace_count, default_workspace_count)
SELECT 
    'conversation_messages',
    COUNT(*),
    COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
    COUNT(CASE WHEN workspace_id = :'default_workspace_id' THEN 1 END)
FROM legalcase.conversation_messages;

-- 验证Storage Service迁移结果
INSERT INTO validation_results (table_name, total_records, null_workspace_count, default_workspace_count)
SELECT 
    'cloud_files',
    COUNT(*),
    COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
    COUNT(CASE WHEN workspace_id = :'default_workspace_id' THEN 1 END)
FROM storage.cloud_files;

-- 验证Messaging Service迁移结果
INSERT INTO validation_results (table_name, total_records, null_workspace_count, default_workspace_count)
SELECT 
    'emails',
    COUNT(*),
    COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
    COUNT(CASE WHEN workspace_id = :'default_workspace_id' THEN 1 END)
FROM messaging.emails;

INSERT INTO validation_results (table_name, total_records, null_workspace_count, default_workspace_count)
SELECT 
    'email_templates',
    COUNT(*),
    COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
    COUNT(CASE WHEN workspace_id = :'default_workspace_id' THEN 1 END)
FROM messaging.email_templates;

-- 更新验证状态
UPDATE validation_results 
SET validation_status = CASE 
    WHEN null_workspace_count = 0 THEN 'PASSED'
    ELSE 'FAILED'
END;

-- 记录验证结果
INSERT INTO migration_log (operation, table_name, affected_rows, status, error_message)
SELECT 
    'VALIDATION',
    table_name,
    total_records,
    validation_status,
    CASE 
        WHEN validation_status = 'FAILED' 
        THEN 'Found ' || null_workspace_count || ' records with NULL workspace_id'
        ELSE NULL
    END
FROM validation_results;

-- 显示验证结果
\echo '=== Migration Validation Results ==='
SELECT 
    table_name,
    total_records,
    null_workspace_count,
    default_workspace_count,
    validation_status
FROM validation_results
ORDER BY table_name;

-- 检查是否有验证失败
DO $$
DECLARE
    failed_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO failed_count 
    FROM validation_results 
    WHERE validation_status = 'FAILED';
    
    IF failed_count > 0 THEN
        RAISE EXCEPTION 'Migration validation failed for % tables', failed_count;
    END IF;
END $$;

-- 记录迁移完成
INSERT INTO migration_log (operation) VALUES ('MIGRATION_COMPLETED');

-- 显示迁移摘要
\echo '=== Migration Summary ==='
SELECT 
    operation,
    table_name,
    affected_rows,
    execution_timestamp,
    status
FROM migration_log
WHERE operation != 'VALIDATION'
ORDER BY id;

COMMIT;

\echo 'Migration completed successfully!'
\echo 'Default workspace ID:' :default_workspace_id