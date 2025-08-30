# CLAUDE.md - Development Workspace

Ginkgoo AI development workspace guidance for Claude Code.

## Project Overview

**Ginkgoo AI** - Multi-service platform for UK immigration lawyers with AI-native document processing, case management, and multi-tenant architecture.

## Active Services Structure

```
be-dev-workspace/                     # Current workspace (all services integrated)
├── be-core-identity/                # OAuth2 authentication server  
├── be-core-gateway/                 # API gateway & BFF pattern
├── be-core-workspace/               # Multi-tenant workspace management
├── be-core-common/                  # Shared utilities library
├── be-legal-case/                   # Legal case management (primary business service)
├── be-core-storage/                 # File storage with R2/S3 integration
├── be-core-messaging/               # Email/messaging with SendGrid
├── be-core-intelligence/            # Python AI service (LangGraph workflows)
├── docker-compose.yml               # Infrastructure orchestration
├── pom.xml                          # Maven parent POM
└── Makefile                         # Cross-service development commands
```

## Technology Stack

- **Java 23** with **Spring Boot 3.4.1**, Spring Security OAuth2, Spring AI 1.0.0
- **PostgreSQL** with Flyway migrations, **Redis** for caching
- **Maven** parent POM for centralized dependency management
- **Python**: FastAPI, LangChain/LangGraph, OpenAI/OpenRouter integration

## Development Commands

### Essential Workflow
```bash
# Start infrastructure
make infra-start

# Build entire ecosystem  
mvn clean install

# Start individual services
cd be-core-identity && mvn spring-boot:run

# Check status
make status
```

### Multi-Service Management
```bash
# Build specific service with dependencies
mvn clean install -pl be-legal-case -am

# Run tests for specific service
mvn test -pl be-core-identity

# Service-specific operations
make start-identity
make logs-service
```

## Language Requirements

**STRICT ENGLISH-ONLY POLICY** for international project standards:

- ✅ **Required**: All code comments, documentation, configs, commit messages, logs, variable names
- ❌ **Forbidden**: Chinese characters in any technical context
- **Exceptions**: User-facing UI text, business domain content, test data

## Architecture Overview

### Multi-Tenant RBAC Model
**Three-layer authorization architecture:**
- **Identity Layer**: Global user authentication (be-core-identity)
- **Workspace Layer**: Tenant-scoped permissions (be-core-workspace) 
- **Resource Layer**: Business resource access control (be-legal-case, be-core-storage)

### Database Schemas
Each service maintains dedicated PostgreSQL schema:
- `identity` - User authentication, `legalcase` - Case management
- `workspace` - Multi-tenant management, `storage` - File metadata
- `messaging` - Email templates

### Key Features
- **Flyway migrations** per service
- **BaseAuditableEntity** for automatic audit tracking
- **JWT tokens** with workspace-scoped permissions
- **Event-driven processing** with Spring Events and SSE

## AI Integration

### Prompt-Oriented Programming
- Template management UI: `/prompt-management.html`
- Multi-model support (GPT-4, Claude, Gemini) via Spring AI
- Cost tracking and Redis caching optimization

### Processing Pipeline
```
Document Upload → OCR Processing → Legal Validation → Profile Consolidation
```

## Configuration

### Environment Variables
```bash
# Core services
POSTGRES_HOST/PORT/DB/USER/PASSWORD
REDIS_HOST/PORT/PASSWORD
AUTH_SERVER  # OAuth issuer URI

# AI integration
OPENAI_API_KEY
OPENROUTER_API_KEY
```

### Service Startup Order
1. Infrastructure (PostgreSQL, Redis) → 2. be-core-identity → 3. be-core-workspace → 4. Business services

## Development Patterns

### Essential Rules
- **Database changes**: Use Flyway migrations only
- **Multi-tenant**: Always validate workspace context via `WorkspaceContextInterceptor`
- **AI features**: Implement via prompt templates
- **Events**: Use Spring `@EventListener` for processing
- **APIs**: Generate OpenAPI documentation

### Service-Specific Access
```bash
# Service configurations
be-{service}/src/main/resources/application.yaml

# Service documentation
be-{service}/CLAUDE.md

# Database migrations
be-{service}/src/main/resources/db/migration/
```