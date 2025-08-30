# Ginkgoo AI Microservices Development Tools
# Provides one-click commands to start, stop and manage all microservices

.PHONY: help setup start stop restart status clean build test logs

# 默认目标
.DEFAULT_GOAL := help

# 颜色定义
BLUE := \033[34m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m

# 基础设施服务
INFRASTRUCTURE_SERVICES := postgres redis consul

# Java microservices
JAVA_SERVICES := be-core-identity be-core-workspace be-legal-case be-core-gateway be-core-storage be-core-messaging

# Python services
PYTHON_SERVICES := be-core-intelligence

# All services
ALL_SERVICES := $(INFRASTRUCTURE_SERVICES) $(JAVA_SERVICES) $(PYTHON_SERVICES)

# Docker Compose file
COMPOSE_FILE := docker-compose.yml

## Show help information
help:
	@echo "$(BLUE)Ginkgoo AI Microservices Development Tools$(NC)"
	@echo "=========================================="
	@echo ""
	@echo "$(GREEN)Basic Commands:$(NC)"
	@echo "  make setup          - Initialize development environment (create .env files)"
	@echo "  make start           - Start all services (infrastructure + applications)"
	@echo "  make stop            - Stop all services"
	@echo "  make restart         - Restart all services"
	@echo "  make status          - Check service status"
	@echo ""
	@echo "$(GREEN)Infrastructure Management:$(NC)"
	@echo "  make infra-start     - Start infrastructure only (PostgreSQL, Redis, Consul)"
	@echo "  make infra-stop      - Stop infrastructure services"
	@echo "  make infra-logs      - View infrastructure logs"
	@echo "  make consul-ui       - Open Consul management UI"
	@echo ""
	@echo "$(GREEN)Application Services Management:$(NC)"
	@echo "  make app-start       - Start all application services"
	@echo "  make app-stop        - Stop all application services"
	@echo "  make app-restart     - Restart all application services"
	@echo ""
	@echo "$(GREEN)Individual Service Management:$(NC)"
	@echo "  make start-identity  - Start identity authentication service"
	@echo "  make start-legal     - Start legal case service"
	@echo "  make start-gateway   - Start API gateway"
	@echo ""
	@echo "$(GREEN)Development Tools:$(NC)"
	@echo "  make build           - Build all Java services"
	@echo "  make test            - Run all tests"
	@echo "  make clean           - Clean build cache"
	@echo "  make logs            - View all service logs"
	@echo "  make logs-identity   - View identity service logs"
	@echo "  make logs-legal      - View legal service logs"
	@echo ""
	@echo "$(GREEN)Database Management:$(NC)"
	@echo "  make db-reset        - Reset database (delete all data)"
	@echo "  make db-migrate      - Run database migrations"
	@echo ""

## Initialize development environment
setup:
	@echo "$(BLUE)Initializing Ginkgoo AI development environment...$(NC)"
	@if [ ! -f ../be-core-identity/.env ]; then \
		echo "$(YELLOW)Creating be-core-identity/.env$(NC)"; \
		cp ../be-core-identity/.env.example ../be-core-identity/.env 2>/dev/null || \
		echo "# Please manually create be-core-identity/.env file"; \
	fi
	@if [ ! -f ../be-legal-case/.env ]; then \
		echo "$(YELLOW)Creating be-legal-case/.env$(NC)"; \
		cp ../be-legal-case/.env.example ../be-legal-case/.env 2>/dev/null || \
		echo "# Please manually create be-legal-case/.env file"; \
	fi
	@echo "$(GREEN)✅ Environment initialization complete$(NC)"
	@echo "$(YELLOW)⚠️  Please edit .env files with actual configuration$(NC)"

## Start infrastructure and provide microservice guidance
start: infra-start
	@echo ""
	@echo "$(GREEN)✅ Infrastructure services are ready!$(NC)"
	@echo ""
	@make app-start

## Stop all services
stop:
	@echo "$(BLUE)Stopping all services...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) down
	@echo "$(GREEN)✅ All services stopped$(NC)"

## Restart all services
restart: stop start

## Check service status
status:
	@echo "$(BLUE)Service status check:$(NC)"
	@echo "=========================================="
	@echo "$(YELLOW)Infrastructure services:$(NC)"
	@for service in $(INFRASTRUCTURE_SERVICES); do \
		if docker-compose -f $(COMPOSE_FILE) ps $$service | grep -q "Up"; then \
			echo "$(GREEN)✅ $$service - Running$(NC)"; \
		else \
			echo "$(RED)❌ $$service - Not running$(NC)"; \
		fi; \
	done
	@echo ""
	@echo "$(YELLOW)Application services:$(NC)"
	@for service in $(JAVA_SERVICES) $(PYTHON_SERVICES); do \
		if docker-compose -f $(COMPOSE_FILE) ps $$service | grep -q "Up"; then \
			echo "$(GREEN)✅ $$service - Running$(NC)"; \
		else \
			echo "$(RED)❌ $$service - Not running$(NC)"; \
		fi; \
	done
	@echo "=========================================="
	@echo "$(BLUE)💡 Tip: For development use infrastructure containers + local IDEA startup$(NC)"

## Start infrastructure services
infra-start:
	@echo "$(BLUE)Starting infrastructure services...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) up -d $(INFRASTRUCTURE_SERVICES)
	@echo "$(GREEN)✅ Infrastructure services started$(NC)"

## Stop infrastructure services
infra-stop:
	@echo "$(BLUE)Stopping infrastructure services...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) stop $(INFRASTRUCTURE_SERVICES)
	@echo "$(GREEN)✅ Infrastructure services stopped$(NC)"

## View infrastructure logs
infra-logs:
	@docker-compose -f $(COMPOSE_FILE) logs -f $(INFRASTRUCTURE_SERVICES)

## Application services guidance (not started via Docker)
app-start:
	@echo "$(YELLOW)📝 Application services should be started locally for debugging:$(NC)"
	@echo ""
	@echo "$(BLUE)Recommended startup order:$(NC)"
	@echo "1. $(GREEN)be-core-identity$(NC) (Port 9000) - Authentication server"
	@echo "2. $(GREEN)be-core-workspace$(NC) (Port 8082) - Multi-tenant workspace"
	@echo "3. $(GREEN)be-legal-case$(NC) (Port 8083) - Legal case management"
	@echo "4. $(GREEN)be-core-storage$(NC) (Port 8084) - File storage service"
	@echo "5. $(GREEN)be-core-messaging$(NC) (Port 8085) - Email/messaging service"
	@echo "6. $(GREEN)be-core-gateway$(NC) (Port 8080) - API gateway"
	@echo "7. $(GREEN)be-core-intelligence$(NC) (Port 8086) - AI/Python service"
	@echo ""
	@echo "$(YELLOW)💡 Start each service in IntelliJ IDEA with Debug mode$(NC)"
	@echo "$(YELLOW)💡 Or use 'mvn spring-boot:run' in each service directory$(NC)"

## Application service guidance (Docker not used for microservices)
app-stop:
	@echo "$(YELLOW)📝 Application services are running locally in IDEA$(NC)"
	@echo "$(YELLOW)💡 Stop them directly from IDEA or terminate the Java processes$(NC)"

## Application service guidance (Docker not used for microservices) 
app-restart:
	@make app-stop
	@make app-start

## Start identity authentication service guidance
start-identity:
	@echo "$(BLUE)📝 To start Identity Authentication Service:$(NC)"
	@echo ""
	@echo "$(YELLOW)Method 1 - IntelliJ IDEA:$(NC)"
	@echo "  1. Open be-core-identity project"
	@echo "  2. Run GinkgooCoreIdentityApplication.java in Debug mode"
	@echo "  3. Service will start on port 9000"
	@echo ""
	@echo "$(YELLOW)Method 2 - Command line:$(NC)"
	@echo "  cd ../be-core-identity && mvn spring-boot:run"

## Start legal case service guidance
start-legal:
	@echo "$(BLUE)📝 To start Legal Case Service:$(NC)"
	@echo ""
	@echo "$(YELLOW)Prerequisites:$(NC) Start be-core-identity and be-core-workspace first"
	@echo ""
	@echo "$(YELLOW)Method 1 - IntelliJ IDEA:$(NC)"
	@echo "  1. Open be-legal-case project"
	@echo "  2. Run GinkgooLegalCaseApplication.java in Debug mode"
	@echo "  3. Service will start on port 8083"
	@echo ""
	@echo "$(YELLOW)Method 2 - Command line:$(NC)"
	@echo "  cd ../be-legal-case && mvn spring-boot:run"

## Start API gateway guidance
start-gateway:
	@echo "$(BLUE)📝 To start API Gateway:$(NC)"
	@echo ""
	@echo "$(YELLOW)Prerequisites:$(NC) Start other services first (identity, workspace, legal-case)"
	@echo ""
	@echo "$(YELLOW)Method 1 - IntelliJ IDEA:$(NC)"
	@echo "  1. Open be-core-gateway project"
	@echo "  2. Run CoreGatewayApplication.java in Debug mode"
	@echo "  3. Service will start on port 8080"
	@echo ""
	@echo "$(YELLOW)Method 2 - Command line:$(NC)"
	@echo "  cd ../be-core-gateway && mvn spring-boot:run"

## Build all Java services
build:
	@echo "$(BLUE)Building all Java services...$(NC)"
	@mvn clean compile -f pom.xml
	@for service in $(JAVA_SERVICES); do \
		if [ -d ../$$service ]; then \
			echo "$(YELLOW)Building $$service...$(NC)"; \
			mvn clean package -DskipTests -f ../$$service/pom.xml; \
		fi; \
	done
	@echo "$(GREEN)✅ All services built successfully$(NC)"

## Run all tests
test:
	@echo "$(BLUE)Running all tests...$(NC)"
	@for service in $(JAVA_SERVICES); do \
		if [ -d ../$$service ]; then \
			echo "$(YELLOW)Testing $$service...$(NC)"; \
			mvn test -f ../$$service/pom.xml; \
		fi; \
	done
	@echo "$(GREEN)✅ All tests completed$(NC)"

## Clean build cache
clean:
	@echo "$(BLUE)Cleaning build cache...$(NC)"
	@mvn clean -f pom.xml
	@for service in $(JAVA_SERVICES); do \
		if [ -d ../$$service ]; then \
			echo "$(YELLOW)Cleaning $$service...$(NC)"; \
			mvn clean -f ../$$service/pom.xml; \
		fi; \
	done
	@docker-compose -f $(COMPOSE_FILE) down -v
	@echo "$(GREEN)✅ Cleanup completed$(NC)"

## View all service logs
logs:
	@docker-compose -f $(COMPOSE_FILE) logs -f

## View identity service logs
logs-identity:
	@docker-compose -f $(COMPOSE_FILE) logs -f be-core-identity

## View legal service logs
logs-legal:
	@docker-compose -f $(COMPOSE_FILE) logs -f be-legal-case

## View gateway logs
logs-gateway:
	@docker-compose -f $(COMPOSE_FILE) logs -f be-core-gateway

## Reset database
db-reset:
	@echo "$(RED)⚠️  This will delete all database data!$(NC)"
	@read -p "Confirm to continue? (y/N): " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "$(BLUE)Resetting database...$(NC)"; \
		docker-compose -f $(COMPOSE_FILE) down -v; \
		docker-compose -f $(COMPOSE_FILE) up -d postgres; \
		sleep 10; \
		echo "$(GREEN)✅ Database reset completed$(NC)"; \
	else \
		echo "$(YELLOW)Operation cancelled$(NC)"; \
	fi

## Run database migrations
db-migrate: infra-start
	@echo "$(BLUE)Running database migrations...$(NC)"
	@sleep 5
	@for service in $(JAVA_SERVICES); do \
		if [ -d ../$$service ] && [ -f ../$$service/pom.xml ]; then \
			echo "$(YELLOW)Migrating $$service database...$(NC)"; \
			mvn flyway:migrate -f ../$$service/pom.xml 2>/dev/null || echo "Skipping $$service"; \
		fi; \
	done
	@echo "$(GREEN)✅ Database migrations completed$(NC)"

## Development mode - Quick restart core services
dev-restart:
	@echo "$(BLUE)Development mode restart (core services only)...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) restart be-core-identity be-legal-case
	@echo "$(GREEN)✅ Core services restart completed$(NC)"

## Production build
prod-build:
	@echo "$(BLUE)Production build...$(NC)"
	@mvn clean package -Pprod -DskipTests
	@echo "$(GREEN)✅ Production build completed$(NC)"

## Open Consul management UI
consul-ui:
	@echo "$(BLUE)Opening Consul management UI...$(NC)"
	@if command -v open >/dev/null 2>&1; then \
		open http://localhost:8500; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open http://localhost:8500; \
	else \
		echo "$(YELLOW)Please visit manually: http://localhost:8500$(NC)"; \
	fi