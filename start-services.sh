#!/bin/bash

# Ginkgoo AI Microservices One-Click Startup Script
# This script is used for quickly starting all services in local development environment

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖环境..."
    
    # 检查Java
    if ! command -v java &> /dev/null; then
        log_error "Java未安装或未在PATH中"
        exit 1
    fi
    
    # 检查Maven
    if ! command -v mvn &> /dev/null; then
        log_error "Maven未安装或未在PATH中"
        exit 1
    fi
    
    # 检查Python (for be-core-intelligence)
    if ! command -v python3 &> /dev/null; then
        log_warning "Python3未安装，be-core-intelligence服务将跳过"
    fi
    
    # 检查Node.js (for React SPA)
    if ! command -v npm &> /dev/null; then
        log_warning "Node.js/npm未安装，React SPA将跳过"
    fi
    
    log_success "依赖检查完成"
}

# 检查.env文件
check_env_files() {
    log_info "检查环境变量配置..."
    
    local services=("be-core-identity" "be-core-workspace" "be-legal-case" "be-core-gateway" "be-core-storage" "be-core-messaging")
    local missing_env=()
    
    for service in "${services[@]}"; do
        if [[ ! -f "${service}/.env" ]]; then
            missing_env+=("${service}")
        fi
    done
    
    if [[ ${#missing_env[@]} -gt 0 ]]; then
        log_warning "缺少.env配置文件的服务: ${missing_env[*]}"
        log_info "请运行 ./setup-env.sh 创建环境变量配置"
        read -p "是否继续启动？(y/n): " continue_without_env
        if [[ "$continue_without_env" != "y" ]]; then
            exit 1
        fi
    fi
    
    log_success "环境变量检查完成"
}

# 检查基础设施服务
check_infrastructure() {
    log_info "检查基础设施服务..."
    
    # 检查PostgreSQL
    if ! nc -z localhost 15432 2>/dev/null; then
        log_warning "PostgreSQL (端口15432) 未运行"
        log_info "请先启动数据库: docker-compose -f docker-compose.dev.yml up -d postgres"
    else
        log_success "PostgreSQL连接正常"
    fi
    
    # 检查Redis
    if ! nc -z localhost 16379 2>/dev/null; then
        log_warning "Redis (端口16379) 未运行"
        log_info "请先启动Redis: docker-compose -f docker-compose.dev.yml up -d redis"
    else
        log_success "Redis连接正常"
    fi
}

# 启动单个Java服务
start_java_service() {
    local service_name=$1
    local service_port=$2
    local wait_time=${3:-30}
    
    log_info "启动 ${service_name} (端口 ${service_port})..."
    
    cd "${service_name}"
    
    # 检查端口是否被占用
    if nc -z localhost "${service_port}" 2>/dev/null; then
        log_warning "${service_name} 端口 ${service_port} 已被占用，跳过启动"
        cd ..
        return 0
    fi
    
    # 后台启动服务
    nohup mvn spring-boot:run > "../logs/${service_name}.log" 2>&1 &
    local pid=$!
    echo $pid > "../logs/${service_name}.pid"
    
    cd ..
    
    log_info "等待 ${service_name} 启动完成 (PID: ${pid})..."
    
    # 等待服务启动
    local count=0
    while [[ $count -lt $wait_time ]]; do
        if nc -z localhost "${service_port}" 2>/dev/null; then
            log_success "${service_name} 启动成功 (端口 ${service_port})"
            return 0
        fi
        sleep 2
        count=$((count + 2))
        printf "."
    done
    
    echo
    log_error "${service_name} 启动超时"
    return 1
}

# 启动Python服务
start_python_service() {
    local service_name=$1
    local service_port=$2
    
    log_info "启动 ${service_name} (端口 ${service_port})..."
    
    if [[ ! -d "${service_name}" ]]; then
        log_warning "${service_name} 目录不存在，跳过"
        return 0
    fi
    
    cd "${service_name}"
    
    # 检查端口是否被占用
    if nc -z localhost "${service_port}" 2>/dev/null; then
        log_warning "${service_name} 端口 ${service_port} 已被占用，跳过启动"
        cd ..
        return 0
    fi
    
    # 安装依赖并启动
    if [[ -f "requirements.txt" ]]; then
        pip3 install -r requirements.txt > /dev/null 2>&1
    fi
    
    # 后台启动服务
    nohup python3 main.py > "../logs/${service_name}.log" 2>&1 &
    local pid=$!
    echo $pid > "../logs/${service_name}.pid"
    
    cd ..
    
    log_success "${service_name} 启动成功 (PID: ${pid})"
}

# 启动React应用
start_react_app() {
    local app_name=$1
    local app_port=$2
    
    log_info "启动 ${app_name} (端口 ${app_port})..."
    
    if [[ ! -d "${app_name}" ]]; then
        log_warning "${app_name} 目录不存在，跳过"
        return 0
    fi
    
    cd "${app_name}"
    
    # 检查端口是否被占用
    if nc -z localhost "${app_port}" 2>/dev/null; then
        log_warning "${app_name} 端口 ${app_port} 已被占用，跳过启动"
        cd ..
        return 0
    fi
    
    # 安装依赖
    if [[ ! -d "node_modules" ]]; then
        log_info "安装 ${app_name} 依赖..."
        npm install
    fi
    
    # 后台启动应用
    nohup npm run dev > "../logs/${app_name}.log" 2>&1 &
    local pid=$!
    echo $pid > "../logs/${app_name}.pid"
    
    cd ..
    
    log_success "${app_name} 启动成功 (PID: ${pid})"
}

# 显示服务状态
show_service_status() {
    log_info "服务状态检查:"
    echo "----------------------------------------"
    
    local services=(
        "be-core-identity:9000"
        "be-core-workspace:8082" 
        "be-legal-case:8083"
        "be-core-gateway:8080"
        "be-core-storage:8084"
        "be-core-messaging:8085"
        "be-core-intelligence:8000"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -r name port <<< "$service"
        if nc -z localhost "$port" 2>/dev/null; then
            echo -e "✅ ${name} (${port}) - ${GREEN}运行中${NC}"
        else
            echo -e "❌ ${name} (${port}) - ${RED}未运行${NC}"
        fi
    done
    
    echo "----------------------------------------"
}

# 停止所有服务
stop_services() {
    log_info "停止所有服务..."
    
    # 停止所有记录的PID
    if [[ -d "logs" ]]; then
        for pidfile in logs/*.pid; do
            if [[ -f "$pidfile" ]]; then
                local pid=$(cat "$pidfile")
                local service=$(basename "$pidfile" .pid)
                if kill -0 "$pid" 2>/dev/null; then
                    log_info "停止 ${service} (PID: ${pid})"
                    kill "$pid"
                fi
                rm -f "$pidfile"
            fi
        done
    fi
    
    log_success "所有服务已停止"
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "    Ginkgoo AI 微服务一键启动脚本"
    echo "=========================================="
    echo -e "${NC}"
    
    # 创建日志目录
    mkdir -p logs
    
    case "${1:-start}" in
        "start")
            check_dependencies
            check_env_files
            check_infrastructure
            
            log_info "开始启动所有服务..."
            
            # Start Java services in dependency order
            start_java_service "be-core-identity" 9000 45
            sleep 5
            
            start_java_service "be-core-workspace" 8082 45
            start_java_service "be-core-storage" 8084 45
            start_java_service "be-core-messaging" 8085 45
            sleep 10
            
            start_java_service "be-legal-case" 8083 60
            sleep 5
            
            start_java_service "be-core-gateway" 8080 45
            
            # Start Python services
            if command -v python3 &> /dev/null; then
                start_python_service "be-core-intelligence" 8000
            fi
            
            # Start React applications
            if command -v npm &> /dev/null; then
                start_react_app "ginkgoo-ai-workspace/react-spa" 3000
            fi
            
            echo
            show_service_status
            
            echo
            log_success "🚀 All services started successfully!"
            echo
            log_info "📝 View logs: tail -f logs/service-name.log"
            log_info "🛑 Stop services: ./start-services.sh stop"
            log_info "📊 Service status: ./start-services.sh status"
            ;;
            
        "stop")
            stop_services
            ;;
            
        "status")
            show_service_status
            ;;
            
        "restart")
            stop_services
            sleep 3
            exec "$0" start
            ;;
            
        *)
            echo "Usage: $0 {start|stop|status|restart}"
            echo "  start   - Start all services (default)"
            echo "  stop    - Stop all services"
            echo "  status  - Show service status"
            echo "  restart - Restart all services"
            exit 1
            ;;
    esac
}

# 捕获退出信号
trap stop_services EXIT INT TERM

# 运行主函数
main "$@"