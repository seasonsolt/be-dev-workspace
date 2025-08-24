#!/bin/bash
# 多租户数据迁移执行脚本
# 将现有无租户数据迁移到默认workspace

set -e

# 配置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    echo -e "${2}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

print_error() {
    print_message "$1" "${RED}"
}

print_success() {
    print_message "$1" "${GREEN}"
}

print_warning() {
    print_message "$1" "${YELLOW}"
}

print_info() {
    print_message "$1" "${BLUE}"
}

# 数据库配置
DB_HOST=${POSTGRES_HOST:-localhost}
DB_PORT=${POSTGRES_PORT:-15432}
DB_NAME=${POSTGRES_DB:-postgres}
DB_USER=${POSTGRES_USER:-postgres}
DB_PASSWORD=${POSTGRES_PASSWORD}

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 生成默认workspace UUID
if [ -z "${DEFAULT_WORKSPACE_ID}" ]; then
    if command -v uuidgen &> /dev/null; then
        DEFAULT_WORKSPACE_ID="default-workspace-$(uuidgen | tr '[:upper:]' '[:lower:]')"
    else
        # 如果没有uuidgen，使用随机字符串
        DEFAULT_WORKSPACE_ID="default-workspace-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 32 | head -n 1)"
    fi
fi

# 备份目录
BACKUP_DIR="${SCRIPT_DIR}/backups/$(date +%Y%m%d_%H%M%S)"

# 显示配置信息
print_info "=== Multi-Tenant Data Migration ==="
print_info "Database Host: $DB_HOST:$DB_PORT"
print_info "Database Name: $DB_NAME"
print_info "Database User: $DB_USER"
print_info "Default Workspace ID: $DEFAULT_WORKSPACE_ID"
print_info "Backup Directory: $BACKUP_DIR"

# 检查数据库连接
print_info "Checking database connection..."
if ! PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;" >/dev/null 2>&1; then
    print_error "Failed to connect to database. Please check your configuration."
    exit 1
fi
print_success "Database connection successful"

# 检查必需的schema是否存在
print_info "Checking required schemas..."
for schema in "identity" "workspace" "legalcase" "storage" "messaging"; do
    if ! PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name = '$schema';" | grep -q $schema; then
        print_warning "Schema '$schema' not found, skipping related migrations"
    else
        print_success "Schema '$schema' found"
    fi
done

# 询问是否创建备份
read -p "Do you want to create a database backup before migration? (y/N): " CREATE_BACKUP
CREATE_BACKUP=${CREATE_BACKUP:-n}

if [[ $CREATE_BACKUP =~ ^[Yy]$ ]]; then
    print_info "Creating database backup..."
    mkdir -p "$BACKUP_DIR"
    
    # 全量备份
    print_info "Creating full database backup..."
    PGPASSWORD=$DB_PASSWORD pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME > "$BACKUP_DIR/full_backup.sql"
    print_success "Full backup created: $BACKUP_DIR/full_backup.sql"
    
    # 按schema分别备份
    for schema in "identity" "workspace" "legalcase" "storage" "messaging"; do
        if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name = '$schema';" | grep -q $schema; then
            print_info "Creating backup for schema: $schema"
            PGPASSWORD=$DB_PASSWORD pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -n $schema > "$BACKUP_DIR/${schema}_backup.sql"
        fi
    done
    print_success "Schema backups completed"
fi

# 显示迁移前统计信息
print_info "Collecting pre-migration statistics..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME << EOF > "$BACKUP_DIR/pre_migration_stats.txt"
-- Pre-migration Statistics
SELECT 'legal_cases' as table_name, COUNT(*) as total_records, 
       COUNT(CASE WHEN workspace_id IS NULL THEN 1 END) as null_workspace_records
FROM legalcase.legal_cases
UNION ALL
SELECT 'case_documents', COUNT(*), 
       COUNT(CASE WHEN workspace_id IS NULL THEN 1 END)
FROM legalcase.case_documents
UNION ALL
SELECT 'profiles', COUNT(*), 
       COUNT(CASE WHEN workspace_id IS NULL THEN 1 END)
FROM legalcase.profiles
UNION ALL
SELECT 'cloud_files', COUNT(*), 
       COUNT(CASE WHEN workspace_id IS NULL THEN 1 END)
FROM storage.cloud_files
UNION ALL
SELECT 'emails', COUNT(*), 
       COUNT(CASE WHEN workspace_id IS NULL THEN 1 END)
FROM messaging.emails;
EOF

# 询问确认
print_warning "This will migrate all existing data without workspace_id to the default workspace."
read -p "Are you sure you want to proceed? (y/N): " CONFIRM_MIGRATION
CONFIRM_MIGRATION=${CONFIRM_MIGRATION:-n}

if [[ ! $CONFIRM_MIGRATION =~ ^[Yy]$ ]]; then
    print_info "Migration cancelled by user"
    exit 0
fi

# 执行迁移
print_info "Starting data migration..."
export PGPASSWORD=$DB_PASSWORD

if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$SCRIPT_DIR/migrate_to_default_workspace.sql" -v default_workspace_id="$DEFAULT_WORKSPACE_ID"; then
    print_success "Migration completed successfully!"
else
    print_error "Migration failed. Check the output above for details."
    
    # 询问是否要回滚
    read -p "Do you want to rollback the migration? (y/N): " ROLLBACK
    ROLLBACK=${ROLLBACK:-n}
    
    if [[ $ROLLBACK =~ ^[Yy]$ ]]; then
        print_info "Starting rollback..."
        if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$SCRIPT_DIR/rollback_migration.sql" -v default_workspace_id="$DEFAULT_WORKSPACE_ID"; then
            print_success "Rollback completed successfully"
        else
            print_error "Rollback failed. Manual intervention may be required."
        fi
    fi
    
    exit 1
fi

# 收集迁移后统计信息
print_info "Collecting post-migration statistics..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME << EOF > "$BACKUP_DIR/post_migration_stats.txt"
-- Post-migration Statistics
SELECT 'legal_cases' as table_name, COUNT(*) as total_records, 
       COUNT(CASE WHEN workspace_id IS NULL THEN 1 END) as null_workspace_records,
       COUNT(CASE WHEN workspace_id = '$DEFAULT_WORKSPACE_ID' THEN 1 END) as default_workspace_records
FROM legalcase.legal_cases
UNION ALL
SELECT 'case_documents', COUNT(*), 
       COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
       COUNT(CASE WHEN workspace_id = '$DEFAULT_WORKSPACE_ID' THEN 1 END)
FROM legalcase.case_documents
UNION ALL
SELECT 'profiles', COUNT(*), 
       COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
       COUNT(CASE WHEN workspace_id = '$DEFAULT_WORKSPACE_ID' THEN 1 END)
FROM legalcase.profiles
UNION ALL
SELECT 'cloud_files', COUNT(*), 
       COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
       COUNT(CASE WHEN workspace_id = '$DEFAULT_WORKSPACE_ID' THEN 1 END)
FROM storage.cloud_files
UNION ALL
SELECT 'emails', COUNT(*), 
       COUNT(CASE WHEN workspace_id IS NULL THEN 1 END),
       COUNT(CASE WHEN workspace_id = '$DEFAULT_WORKSPACE_ID' THEN 1 END)
FROM messaging.emails;
EOF

# 显示迁移摘要
print_success "=== Migration Summary ==="
print_info "Default Workspace ID: $DEFAULT_WORKSPACE_ID"
print_info "Backup Location: $BACKUP_DIR"
print_info "Pre-migration stats: $BACKUP_DIR/pre_migration_stats.txt"
print_info "Post-migration stats: $BACKUP_DIR/post_migration_stats.txt"

# 保存默认workspace ID到文件
echo "$DEFAULT_WORKSPACE_ID" > "$BACKUP_DIR/default_workspace_id.txt"
print_info "Default workspace ID saved to: $BACKUP_DIR/default_workspace_id.txt"

# 显示后续步骤
print_success "=== Next Steps ==="
print_info "1. Verify application functionality with the migrated data"
print_info "2. Update application configuration if needed"
print_info "3. Monitor system logs for any multi-tenant related issues"
print_info "4. Consider running performance tests to ensure query optimization"

print_success "Migration completed successfully!"