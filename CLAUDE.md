# CLAUDE.md - Development Workspace

This file provides guidance to Claude Code (claude.ai/code) when working with the Ginkgoo AI development workspace.

## Working Directory Structure

**Current Workspace**: `/path/to/ginkgoo-ai/be-dev-workspace/`

**Parent Directory Structure**:
```
ginkgoo-ai/                           # Parent directory
├── be-dev-workspace/                 # ← Current Claude Code workspace
│   ├── CLAUDE.md                    # This file - development guidance
│   ├── docker-compose.yml           # Infrastructure orchestration
│   ├── pom.xml                      # Maven parent POM for dependency management
│   ├── Makefile                     # Cross-service development commands
│   └── scripts/                     # Development automation scripts
├── be-core-identity/                # OAuth2 authentication server
├── be-legal-case/                   # Legal case management service
├── be-core-gateway/                 # API gateway service
├── be-core-workspace/               # Multi-tenant workspace service
├── be-core-messaging/               # Email/messaging service
├── be-core-storage/                 # File storage service
├── be-core-intelligence/            # Python AI service (LangGraph)
└── be-core-common/                  # Shared utilities library
```

## Cross-Service Development Access

Claude Code can access all microservices via relative paths from this workspace:

### Reading Service Code
```bash
# Service configurations
../be-core-identity/src/main/resources/application.yaml
../be-legal-case/pom.xml
../be-core-gateway/src/main/java/...

# Service documentation  
../be-core-identity/CLAUDE.md
../be-legal-case/CLAUDE.md

# Service source code
../be-core-identity/src/main/java/com/ginkgooai/core/identity/
../be-legal-case/src/main/java/com/ginkgooai/legalcase/
```

### Cross-Service Commands
Use Makefile commands to operate across services:
```bash
make status              # Check all service status
make infra-start        # Start infrastructure (PostgreSQL, Redis, Consul)
make build-all          # Build all Java services via parent POM
make start-identity     # Start identity service locally
make logs-service       # View service logs
```

### Development Workflow
```bash
# 1. Start infrastructure
make infra-start

# 2. Build all services from parent POM
mvn clean install

# 3. Start individual services in IDEA or via Maven
cd ../be-core-identity && mvn spring-boot:run

# 4. Check service status
make status
```

## Internationalization Requirements

This is an **international project** with strict language requirements:

### Code and Documentation Language Policy
- **English Only**: All code comments, documentation, configuration files, and technical communication must be in English
- **No Chinese**: Never use Chinese characters in any technical context (code, configs, docs, commit messages)
- **Examples**:
  - ✅ Good: `# Infrastructure services configuration`
  - ❌ Bad: `# 基础设施服务配置`
  - ✅ Good: `DATABASE_CONNECTION_ERROR`
  - ❌ Bad: `数据库连接错误`

### File Types Requiring English
- Configuration files (docker-compose.yml, application.yaml, etc.)
- Documentation files (README.md, CLAUDE.md, etc.)
- Code comments and JavaDoc
- Git commit messages
- Environment variable names and values
- Log messages and error messages
- Makefile targets and descriptions

### Exceptions
- User-facing UI text may be localized
- Business domain content may be in target market language
- Test data may use various languages for testing purposes

**Always ensure all technical documentation and code follows English-only policy to maintain international project standards.**

## Project Overview

This is the **Ginkgoo AI** ecosystem - a comprehensive multi-service platform for UK immigration lawyers featuring AI-native document processing, case management, and multi-tenant architecture. The system combines traditional microservices with cutting-edge AI capabilities for legal workflow automation.

## Architecture Overview

### Maven Multi-Module Structure
The project uses a **centralized parent POM** (`pom.xml`) for managing:
- Common dependency versions and configurations
- Plugin management across all Java services  
- Build profiles and repository configurations
- Simplified multi-service builds with `mvn clean install`

### Core Infrastructure Services
- **be-core-identity**: OAuth 2.0/OIDC authentication server with JWT, MFA, and social login
- **be-core-gateway**: API gateway for routing and centralized security
- **be-core-workspace**: Multi-tenant workspace management with planned RBAC architecture
- **be-core-common**: Shared utilities and common functionality library

### Business Domain Services
- **be-legal-case**: Primary legal case management with AI-powered document processing pipeline
- **be-core-storage**: File storage service with R2/S3 cloud integration
- **be-core-messaging**: Email/messaging service with SendGrid integration

### AI & Intelligence Services
- **be-core-intelligence**: Python-based visa form automation using LangGraph workflows


## Technology Stack

### Backend Services (Java)
- **Java 23** with **Spring Boot 3.4.1**
- **Spring Security** with OAuth2 Authorization Server
- **Spring AI 1.0.0** for AI model abstraction
- **PostgreSQL** with Flyway migrations
- **Redis** for caching and distributed locking
- **Maven** with centralized dependency management via parent POM

### Python Services
- **FastAPI** with **SQLAlchemy**
- **LangChain + LangGraph** for AI workflows
- **OpenAI** and **OpenRouter** integration

## Common Development Commands

### Multi-Service Management
```bash
# Build entire ecosystem from root directory
mvn clean install

# Build specific service
mvn clean install -pl be-legal-case

# Build with dependencies
mvn clean install -pl be-legal-case -am

# Run tests for all services
mvn test

# Run tests for specific service
mvn test -pl be-core-identity
```

### Individual Java Services
```bash
# Build and run any Java service (from service directory)
mvn clean compile
mvn spring-boot:run
mvn test
mvn clean package

# Run specific test class
mvn test -Dtest=ClassNameTest

# Database migrations (auto-run on startup)
mvn flyway:migrate
mvn flyway:info
```

### Python Services
```bash
# Setup and run Python services
pip install -r requirements.txt
python main.py

# For FastAPI services
uvicorn main:app --reload
```

## Database Architecture

### Schema Organization
Each service maintains its own PostgreSQL schema:
- `identity` - User authentication and global roles
- `legalcase` - Case management and document processing
- `workspace` - Multi-tenant workspace management
- `messaging` - Email templates and messaging history
- `storage` - File metadata and cloud storage references
- Service-specific schemas follow this pattern

### Key Database Features
- **Flyway migrations** with service-specific migration tables (`flyway_schema_history`)
- **Audit entities** via `BaseAuditableEntity` with automatic created/updated tracking
- **Logical deletion** support via `BaseLogicalDeleteEntity`
- **JSON/JSONB** columns for flexible data structures
- **Vector extensions** (pgvector) for AI embeddings

## Multi-Tenant RBAC Architecture

The system implements a sophisticated multi-tenant RBAC model:

### Service Responsibilities
- **be-core-identity**: Global user management and JWT token generation
- **be-core-workspace**: Tenant-level roles, permissions, and member management
- **Business services**: Resource-level access control and validation

### JWT Token Structure
Tokens include workspace-scoped permissions:
```json
{
  "sub": "user-id",
  "workspaces": {
    "workspace-id": {
      "roles": ["SENIOR_LAWYER"],
      "permissions": ["case:*", "document:read"]
    }
  },
  "active_workspace": "workspace-id"
}
```

### Permission Format
Uses `resource:action` format with wildcard support:
- `case:create`, `case:read`, `case:*`
- `document:upload`, `document:delete`

## AI Integration Patterns

### Prompt-Oriented Programming
The system uses **prompt templates as first-class entities**:
- Template management via UI at `/prompt-management.html`
- Multi-model support (GPT-4, Claude, Gemini)
- Cost tracking and performance analytics
- Redis caching for optimization

### AI Processing Pipeline
**be-legal-case** implements a multi-stage pipeline:
```
Document Upload → OCR Processing → Legal Validation → Profile Consolidation
```

### Event-Driven Architecture
- **Dual event system**: Status updates + rich content delivery
- **SSE streams** for real-time UI updates
- **Spring Events** for internal service communication

## Configuration Patterns

### Environment Variables
```bash
# Database connections
POSTGRES_HOST/PORT/DB/USER/PASSWORD

# Service discovery
CORE_IDENTITY_HOST/PORT
AUTH_SERVER # OAuth issuer URI

# AI integration
OPENAI_API_KEY
OPENROUTER_API_KEY

# Infrastructure
REDIS_HOST/PORT/PASSWORD
```

### Application Configuration
- **YAML-based** configuration in `application.yaml`
- **Environment-specific** overrides
- **Feature flags** for processing modes
- **Validation settings** for comprehensive input checking

## Inter-Service Communication

### Authentication Flow
1. JWT tokens for service-to-service calls  
2. Redis-based session storage
3. Custom JWT claims for workspace permissions

### Service Integration
- **OpenFeign** clients for service calls
- **Circuit breaker** patterns with Resilience4j
- **OpenAPI** documentation for all REST APIs
- **Event-driven** communication where appropriate

## Development Workflow

### Service Startup Order
1. **Infrastructure**: PostgreSQL, Redis
2. **be-core-identity**: Authentication foundation
3. **be-core-gateway**: API gateway (if needed)
4. **be-core-workspace**: Multi-tenant management (if needed)
5. **be-core-storage**: File storage service
6. **be-core-messaging**: Email/messaging service
7. **be-legal-case**: Primary business service
8. **be-core-intelligence**: AI/Python service

### Key Development Patterns
- **Database changes**: Always use Flyway migrations
- **AI features**: Implement via prompt templates
- **New APIs**: Generate OpenAPI documentation
- **Event processing**: Use Spring @EventListener
- **Multi-tenant**: Always validate workspace context
- **Caching**: Leverage Redis for performance

### Service-Specific Notes
- **be-legal-case**: Uses `legalcase` schema, includes AI processing pipeline with comprehensive legal document processing, validation, and profile consolidation
- **be-core-identity**: Uses `identity` schema, handles OAuth2 flows with MFA and social login integration
- **be-core-workspace**: Uses `workspace` schema, provides multi-tenant RBAC architecture foundation
- **be-core-storage**: Uses `storage` schema, manages file storage with R2/S3 integration and video metadata extraction
- **be-core-messaging**: Uses `messaging` schema, handles email templates and SendGrid integration
- **be-core-intelligence**: Python FastAPI service using LangGraph for visa form automation workflows

## Important Files and Locations

### Configuration
- `src/main/resources/application.yaml` - Service configuration
- `src/main/resources/db/migration/` - Flyway database migrations

### AI Integration
- `/prompt-management.html` - Prompt template management UI
- `src/main/resources/prompts/` - Prompt template files

### Documentation
- Individual service `CLAUDE.md` files contain service-specific guidance
- `MULTI_TENANT_RBAC_ARCHITECTURE.md` - Detailed RBAC design specification

## Architecture Principles

### Microservices Design
- **Domain-driven** service boundaries
- **Independent data stores** per service
- **API-first** design with OpenAPI specifications
- **Shared common library** for utilities

### AI-Native Architecture
- **Prompt templates** as configuration
- **Multi-model abstraction** layer
- **Cost tracking** and optimization
- **Event-driven processing** pipelines

### Security-First Approach
- **OAuth 2.0/OIDC** standards compliance
- **Fine-grained RBAC** with workspace isolation
- **JWT with custom claims** for rich authorization
- **Multi-factor authentication** support

## OAuth 2.0 Architecture View

Beyond the microservices perspective, the Ginkgoo AI ecosystem implements a comprehensive **OAuth 2.0 architecture** with **Backend for Frontend (BFF) pattern** for enhanced security and user experience.

### OAuth 2.0 Roles & Components

#### **Authorization Server** (`be-core-identity`)
- **Primary OAuth 2.0/OIDC Provider**: Issues access tokens, refresh tokens, and ID tokens
- **Client Registry**: Manages OAuth2 client registrations and configurations
- **User Authentication**: Handles login, MFA, social login, and password recovery
- **Token Introspection**: Validates tokens and provides client/user metadata
- **Custom Grant Types**: Implements share code grant for special authentication flows

#### **Resource Owners** (End Users)
- **UK Immigration Lawyers**: Primary users with workspace-scoped permissions
- **Legal Staff**: Assistant lawyers, paralegals with limited access
- **Clients**: End clients with restricted document access (future)

#### **Clients** (Applications)
- **BFF Services** (`be-core-gateway`): Backend for Frontend acting as confidential client
- **Service Clients**: Internal services using Client Credentials flow
- **Chrome Extension**: Public client using Authorization Code + PKCE
- **Future SPAs**: Web applications using Authorization Code + PKCE

#### **Resource Servers** (Protected APIs)
All business services act as OAuth 2.0 Resource Servers:
- **`be-legal-case`**: Legal case management and document processing APIs
- **`be-core-storage`**: File storage and cloud integration APIs
- **`be-core-messaging`**: Email templates and messaging APIs
- **`be-core-workspace`**: Multi-tenant workspace and member management APIs

### Backend for Frontend (BFF) Pattern

Following Auth0's BFF pattern guidelines, `be-core-gateway` implements a **security-focused BFF**:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Frontend      │    │   BFF Gateway    │    │  Resource Servers   │
│   (Browser)     │    │  (core-gateway)  │    │  (Business APIs)    │
├─────────────────┤    ├──────────────────┤    ├─────────────────────┤
│ • Session-based │◄──►│ • HTTP-Only      │    │ • JWT Validation    │
│   authentication│    │   Cookies        │    │ • Scope Enforcement │
│ • No token      │    │ • Token Storage  │    │ • Resource Access   │
│   exposure      │    │ • Token Refresh  │    │   Control           │
│ • API calls     │    │ • API Aggregation│    │                     │
│   through BFF   │    │ • CSRF Protection│    │                     │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
```

**BFF Security Benefits**:
- **Token Security**: Access tokens never exposed to browser
- **HTTP-Only Cookies**: Session management with CSRF protection
- **Token Refresh**: Automatic token refresh without frontend involvement
- **API Aggregation**: Single endpoint for complex frontend operations
- **Simplified Frontend**: No OAuth complexity in frontend code

### OAuth 2.0 Flows Implementation

#### **BFF Authentication Flow** (Primary)
```
1. User → Frontend → BFF: Login request
2. BFF → Authorization Server: Authorization Code flow
3. Authorization Server → BFF: Access + Refresh tokens
4. BFF → Frontend: HTTP-Only session cookie
5. Frontend → BFF: API requests with session
6. BFF → Resource Servers: API calls with access token
```

#### **Service-to-Service Flow** (Client Credentials)
```
1. Service A → Authorization Server: Client credentials
2. Authorization Server → Service A: Access token
3. Service A → Service B: API call with Bearer token
4. Service B: Validate token + enforce permissions
```

#### **Custom Share Code Flow** (Special Cases)
```
1. User → Authorization Server: Share code + credentials
2. Authorization Server: Validate share code
3. Authorization Server → Client: Access token with limited scope
```

### Multi-Tenant Authorization Architecture

**Three-Layer Authorization Model**:

```
┌─────────────────────────────────────────────────────────────┐
│               Identity Layer (Global)                       │
│  • User authentication and identity                         │
│  • Global roles and permissions                             │
│  • be-core-identity (Authorization Server)                  │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│              Workspace Layer (Tenant)                       │
│  • Workspace-scoped permissions                             │
│  • Member roles within workspace                            │
│  • be-core-workspace (Resource Server)                      │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│              Resource Layer (Business)                      │
│  • Case-specific access control                             │
│  • Document-level permissions                               │
│  • be-legal-case, be-core-storage (Resource Servers)       │
└─────────────────────────────────────────────────────────────┘
```

### JWT Token Structure

**Access Token Claims**:
```json
{
  "sub": "user-uuid",
  "iss": "https://identity.ginkgoo.ai",
  "aud": ["legal-case-api", "storage-api"],
  "scope": "case:read case:write document:upload",
  "workspaces": {
    "workspace-uuid": {
      "roles": ["SENIOR_LAWYER", "CASE_MANAGER"],
      "permissions": ["case:*", "document:*", "member:invite"]
    }
  },
  "active_workspace": "workspace-uuid",
  "exp": 1735689600,
  "iat": 1735603200
}
```

### Resource Server Authorization

Each Resource Server implements **scope-based authorization**:

```java
// Example: Legal Case API
@PreAuthorize("hasScope('case:read') and hasWorkspaceAccess(#caseId)")
public CaseResponse getCase(@PathVariable String caseId) {
    // Workspace context validation
    // Resource-level access control
}
```

**Permission Format**: `resource:action` with wildcard support
- `case:create`, `case:read`, `case:*`
- `document:upload`, `document:delete`, `document:*`
- `workspace:manage`, `member:invite`

### Security Boundaries & Token Validation

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Public Zone   │    │  Protected Zone  │    │  Internal Zone  │
│                 │    │                  │    │                 │
│ • Web Frontend  │───▶│ • BFF Gateway    │───▶│ • Resource      │
│ • Mobile Apps   │    │ • Auth Server    │    │   Servers       │
│ • Extensions    │    │ • Token          │    │ • Databases     │
│                 │    │   Validation     │    │ • Redis         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
   Session Cookies       JWT Access Tokens      Internal APIs
```

### OAuth 2.0 Compliance Features

- **PKCE**: Authorization Code flow protection
- **State Parameter**: CSRF protection for authorization requests
- **Scope-based Access**: Fine-grained permission model
- **Token Introspection**: RFC 7662 compliance for token validation
- **OIDC**: OpenID Connect for identity information
- **Custom Claims**: Workspace and multi-tenant authorization
- **Token Revocation**: Centralized token lifecycle management

This OAuth 2.0 architecture ensures **secure, scalable, and compliant** authentication and authorization across the entire Ginkgoo AI ecosystem while maintaining excellent user experience through the BFF pattern.

## Current Active Services

The streamlined Ginkgoo AI ecosystem now focuses on core functionality:

### Core Services (7 active)
1. **be-core-identity** - Authentication & OAuth2 server
2. **be-core-gateway** - API gateway & routing  
3. **be-core-workspace** - Multi-tenant workspace management
4. **be-core-common** - Shared utilities library
5. **be-legal-case** - Main legal case management with AI processing
6. **be-core-storage** - File storage & cloud integration
7. **be-core-messaging** - Email/messaging service

### AI & Intelligence
- **be-core-intelligence** - Python/LangGraph visa form automation


This streamlined ecosystem focuses on core legal case management functionality while maintaining the foundational architecture for future expansion. Each service maintains clear boundaries and contributes to a cohesive user experience for UK immigration lawyers.