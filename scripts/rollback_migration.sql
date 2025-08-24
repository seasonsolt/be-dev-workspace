-- 多租户数据迁移回滚脚本
-- 将数据从默认workspace回滚到无租户状态
-- 执行方式: psql -f rollback_migration.sql -v default_workspace_id='your-uuid-here'

\set ON_ERROR_STOP on

-- 设置默认workspace ID
\set default_workspace_id 'default-workspace-' :default_workspace_id

BEGIN;

-- 创建回滚日志表
CREATE TABLE IF NOT EXISTS rollback_log (
    id SERIAL PRIMARY KEY,
    operation VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    affected_rows INTEGER,
    execution_timestamp TIMESTAMP DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'SUCCESS',
    error_message TEXT
);

-- 记录回滚开始
INSERT INTO rollback_log (operation) VALUES ('ROLLBACK_START');

\echo 'Starting migration rollback...'
\echo 'Default workspace ID:' :default_workspace_id

-- =============================================================================
-- Phase 1: Legal Case Service数据回滚
-- =============================================================================

-- 回滚legal_cases表
WITH rolled_back_cases AS (
    UPDATE legalcase.legal_cases 
    SET workspace_id = NULL
    WHERE workspace_id = :'default_workspace_id'
    RETURNING id
)
INSERT INTO rollback_log (operation, table_name, affected_rows)
VALUES ('ROLLBACK_LEGAL_CASES', 'legal_cases', (SELECT COUNT(*) FROM rolled_back_cases));

-- 回滚case_documents表  
WITH rolled_back_documents AS (
    UPDATE legalcase.case_documents
    SET workspace_id = NULL
    WHERE workspace_id = :'default_workspace_id'
    RETURNING id
)
INSERT INTO rollback_log (operation, table_name, affected_rows)
VALUES ('ROLLBACK_CASE_DOCUMENTS', 'case_documents', (SELECT COUNT(*) FROM rolled_back_documents));

-- 回滚profiles表
WITH rolled_back_profiles AS (
    UPDATE legalcase.profiles
    SET workspace_id = NULL
    WHERE workspace_id = :'default_workspace_id'
    RETURNING id
)
INSERT INTO rollback_log (operation, table_name, affected_rows)
VALUES ('ROLLBACK_PROFILES', 'profiles', (SELECT COUNT(*) FROM rolled_back_profiles));

-- 回滚conversation_messages表
WITH rolled_back_messages AS (
    UPDATE legalcase.conversation_messages
    SET workspace_id = NULL
    WHERE workspace_id = :'default_workspace_id'
    RETURNING id
)
INSERT INTO rollback_log (operation, table_name, affected_rows)
VALUES ('ROLLBACK_CONVERSATION_MESSAGES', 'conversation_messages', (SELECT COUNT(*) FROM rolled_back_messages));

-- 回滚legal_rules表
WITH rolled_back_rules AS (
    UPDATE legalcase.legal_rules  
    SET workspace_id = NULL
    WHERE workspace_id = :'default_workspace_id'
    RETURNING id
)
INSERT INTO rollback_log (operation, table_name, affected_rows)
VALUES ('ROLLBACK_LEGAL_RULES', 'legal_rules', (SELECT COUNT(*) FROM rolled_back_rules));

-- 回滚legal_validation_results表
WITH rolled_back_validations AS (
    UPDATE legalcase.legal_validation_results
    SET workspace_id = NULL
    WHERE workspace_id = :'default_workspace_id'
    RETURNING id
)
INSERT INTO rollback_log (operation, table_name, affected_rows)
VALUES ('ROLLBACK_LEGAL_VALIDATION_RESULTS', 'legal_validation_results', (SELECT COUNT(*) FROM rolled_back_validations));

-- 回滚prompt_templates表
WITH rolled_back_templates AS (
    UPDATE legalcase.prompt_templates
    SET workspace_id = NULL
    WHERE workspace_id = :'default_workspace_id'
    RETURNING id
)
INSERT INTO rollback_log (operation, table_name, affected_rows)
VALUES ('ROLLBACK_PROMPT_TEMPLATES', 'prompt_templates', (SELECT COUNT(*) FROM rolled_back_templates));

-- 回滚prompt_executions表
WITH rolled_back_executions AS (
    UPDATE legalcase.prompt_executions
    SET workspace_id = NULL
    WHERE workspace_id = :'default_workspace_id'
    RETURNING id
)
INSERT INTO rollback_log (operation, table_name, affected_rows)
VALUES ('ROLLBACK_PROMPT_EXECUTIONS', 'prompt_executions', (SELECT COUNT(*) FROM rolled_back_executions));

-- 回滚profile_schemas表
WITH rolled_back_schemas AS (
    UPDATE legalcase.profile_schemas
    SET workspace_id = NULL
    WHERE workspace_id = :'default_workspace_id'
    RETURNING id
)
INSERT INTO rollback_log (operation, table_name, affected_rows)
VALUES ('ROLLBACK_PROFILE_SCHEMAS', 'profile_schemas', (SELECT COUNT(*) FROM rolled_back_schemas));

-- =============================================================================
-- Phase 2: Storage Service数据回滚
-- =============================================================================

-- 回滚cloud_files表
WITH rolled_back_files AS (
    UPDATE storage.cloud_files
    SET workspace_id = NULL
    WHERE workspace_id = :'default_workspace_id'
    RETURNING id
)
INSERT INTO rollback_log (operation, table_name, affected_rows)
VALUES ('ROLLBACK_CLOUD_FILES', 'cloud_files', (SELECT COUNT(*) FROM rolled_back_files));

-- 回滚video_metadata表（如果存在）
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'storage' AND table_name = 'video_metadata') THEN
        WITH rolled_back_metadata AS (
            UPDATE storage.video_metadata
            SET workspace_id = NULL
            WHERE workspace_id = :'default_workspace_id'
            RETURNING id
        )
        INSERT INTO rollback_log (operation, table_name, affected_rows)
        VALUES ('ROLLBACK_VIDEO_METADATA', 'video_metadata', (SELECT COUNT(*) FROM rolled_back_metadata));
    ELSE
        INSERT INTO rollback_log (operation, table_name, affected_rows)
        VALUES ('SKIP_VIDEO_METADATA_ROLLBACK', 'video_metadata', 0);
    END IF;
END $$;

-- =============================================================================
-- Phase 3: Messaging Service数据回滚
-- =============================================================================

-- 回滚emails表
WITH rolled_back_emails AS (
    UPDATE messaging.emails
    SET workspace_id = NULL
    WHERE workspace_id = :'default_workspace_id'
    RETURNING id
)
INSERT INTO rollback_log (operation, table_name, affected_rows)
VALUES ('ROLLBACK_EMAILS', 'emails', (SELECT COUNT(*) FROM rolled_back_emails));

-- 回滚email_templates表  
WITH rolled_back_email_templates AS (
    UPDATE messaging.email_templates  
    SET workspace_id = NULL
    WHERE workspace_id = :'default_workspace_id'
    RETURNING id
)
INSERT INTO rollback_log (operation, table_name, affected_rows)
VALUES ('ROLLBACK_EMAIL_TEMPLATES', 'email_templates', (SELECT COUNT(*) FROM rolled_back_email_templates));

-- =============================================================================
-- Phase 4: 清理默认Workspace成员关系（可选）
-- =============================================================================

-- 注意：这里不删除默认workspace本身，只删除成员关系
-- 删除默认workspace的成员关系
WITH deleted_members AS (
    DELETE FROM workspace.workspace_members
    WHERE workspace_id = :'default_workspace_id'
    AND created_by = 'system-migration'
    RETURNING id
)
INSERT INTO rollback_log (operation, table_name, affected_rows)
VALUES ('REMOVE_DEFAULT_WORKSPACE_MEMBERS', 'workspace_members', (SELECT COUNT(*) FROM deleted_members));

-- =============================================================================
-- Phase 5: 回滚验证
-- =============================================================================

-- 创建验证结果表
CREATE TEMP TABLE rollback_validation_results (
    table_name VARCHAR(100),
    total_records INTEGER,
    null_workspace_count INTEGER,
    default_workspace_count INTEGER,
    validation_status VARCHAR(20)
);

-- 验证Legal Case Service回滚结果
INSERT INTO rollback_validation_results (table_name, total_records, null_workspace_count, default_workspace_count)
SELECT 
    'legal_cases',
    COUNT(*),
    COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
    COUNT(CASE WHEN workspace_id = :'default_workspace_id' THEN 1 END)
FROM legalcase.legal_cases;

INSERT INTO rollback_validation_results (table_name, total_records, null_workspace_count, default_workspace_count)
SELECT 
    'case_documents',
    COUNT(*),
    COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
    COUNT(CASE WHEN workspace_id = :'default_workspace_id' THEN 1 END)
FROM legalcase.case_documents;

INSERT INTO rollback_validation_results (table_name, total_records, null_workspace_count, default_workspace_count)
SELECT 
    'profiles',
    COUNT(*),
    COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
    COUNT(CASE WHEN workspace_id = :'default_workspace_id' THEN 1 END)
FROM legalcase.profiles;

-- 验证Storage Service回滚结果
INSERT INTO rollback_validation_results (table_name, total_records, null_workspace_count, default_workspace_count)
SELECT 
    'cloud_files',
    COUNT(*),
    COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
    COUNT(CASE WHEN workspace_id = :'default_workspace_id' THEN 1 END)
FROM storage.cloud_files;

-- 验证Messaging Service回滚结果
INSERT INTO rollback_validation_results (table_name, total_records, null_workspace_count, default_workspace_count)
SELECT 
    'emails',
    COUNT(*),
    COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
    COUNT(CASE WHEN workspace_id = :'default_workspace_id' THEN 1 END)
FROM messaging.emails;

-- 更新验证状态
UPDATE rollback_validation_results 
SET validation_status = CASE 
    WHEN default_workspace_count = 0 THEN 'PASSED'
    ELSE 'FAILED'
END;

-- 记录验证结果
INSERT INTO rollback_log (operation, table_name, affected_rows, status, error_message)
SELECT 
    'ROLLBACK_VALIDATION',
    table_name,
    total_records,
    validation_status,
    CASE 
        WHEN validation_status = 'FAILED' 
        THEN 'Found ' || default_workspace_count || ' records still with default workspace_id'
        ELSE NULL
    END
FROM rollback_validation_results;

-- 显示验证结果
\echo '=== Rollback Validation Results ==='
SELECT 
    table_name,
    total_records,
    null_workspace_count,
    default_workspace_count,
    validation_status
FROM rollback_validation_results
ORDER BY table_name;

-- 检查是否有验证失败
DO $$
DECLARE
    failed_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO failed_count 
    FROM rollback_validation_results 
    WHERE validation_status = 'FAILED';
    
    IF failed_count > 0 THEN
        RAISE EXCEPTION 'Rollback validation failed for % tables', failed_count;
    END IF;
END $$;

-- 记录回滚完成
INSERT INTO rollback_log (operation) VALUES ('ROLLBACK_COMPLETED');

-- 显示回滚摘要
\echo '=== Rollback Summary ==='
SELECT 
    operation,
    table_name,
    affected_rows,
    execution_timestamp,
    status
FROM rollback_log
WHERE operation != 'ROLLBACK_VALIDATION'
ORDER BY id;

COMMIT;

\echo 'Rollback completed successfully!'