# Multi-Tenant RBAC Integration Testing Strategy

## Overview

This document outlines the comprehensive integration testing strategy for validating multi-tenant RBAC functionality across the Ginkgoo AI microservices ecosystem.

## Testing Architecture

### 1. Testing Levels

```
┌─────────────────────────────────────────────────────────────┐
│                    E2E Testing                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Integration Testing                      │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │          Component Testing                      │  │  │
│  │  │  ┌───────────────────────────────────────────┐  │  │  │
│  │  │  │            Unit Testing                   │  │  │  │
│  │  │  └───────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┐  │
└─────────────────────────────────────────────────────────────┘
```

### 2. Test Categories

#### A. Unit Tests (Already Implemented)
- Individual service method testing
- Security component isolation testing
- Permission validation logic testing

#### B. Integration Tests (Service Level)
- Database integration with test containers
- JWT token generation and validation
- Inter-service communication testing

#### C. Contract Tests
- API contract validation between services
- JWT token structure validation
- Permission claim format verification

#### D. End-to-End Tests
- Complete user journey testing
- Multi-workspace scenario testing
- Permission inheritance validation

## Integration Test Implementation

### 1. Database Integration Tests

#### Test Containers Setup
```yaml
# docker-compose.test.yml
version: '3.8'
services:
  postgres-test:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: test_db
      POSTGRES_USER: test_user
      POSTGRES_PASSWORD: test_pass
    ports:
      - "5433:5432"
    
  redis-test:
    image: redis:7-alpine
    ports:
      - "6380:6379"
```

#### Base Integration Test Configuration
```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@ActiveProfiles("integration-test")
public abstract class BaseIntegrationTest {
    
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15-alpine")
        .withDatabaseName("test_db")
        .withUsername("test_user")
        .withPassword("test_pass");
    
    @Container
    static GenericContainer<?> redis = new GenericContainer<>("redis:7-alpine")
        .withExposedPorts(6379);
    
    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.redis.host", redis::getHost);
        registry.add("spring.redis.port", () -> redis.getMappedPort(6379));
    }
}
```

### 2. Service-Level Integration Tests

#### Workspace Service Integration Test
```java
@SpringBootTest
@Transactional
class WorkspaceServiceIntegrationTest extends BaseIntegrationTest {
    
    @Autowired
    private WorkspacePermissionService permissionService;
    
    @Autowired
    private TestEntityManager entityManager;
    
    @Test
    void testCompletePermissionFlow() {
        // Create test data
        Workspace workspace = createTestWorkspace();
        WorkspaceMember member = createTestMember(workspace);
        WorkspaceCustomRole role = createTestRole(workspace);
        Set<Permission> permissions = createTestPermissions();
        
        // Assign permissions through role
        role.setPermissions(permissions);
        member.setCustomRoles(Set.of(role));
        
        entityManager.persistAndFlush(workspace);
        entityManager.persistAndFlush(member);
        entityManager.persistAndFlush(role);
        
        // Test permission validation
        UserWorkspacePermissions result = permissionService.getUserPermissions(
            member.getUserId(), workspace.getId()
        );
        
        assertThat(result.getPermissions()).contains("case:read", "case:write");
        assertThat(result.getIsActive()).isTrue();
        
        // Test specific permission checks
        assertThat(permissionService.hasPermission(
            member.getUserId(), workspace.getId(), "case:read"
        )).isTrue();
        
        assertThat(permissionService.hasPermission(
            member.getUserId(), workspace.getId(), "case:delete"
        )).isFalse();
    }
}
```

### 3. Cross-Service Integration Tests

#### JWT Token Integration Test
```java
@SpringBootTest(classes = {CoreIdentityApplication.class})
@TestPropertySource(properties = {
    "core-workspace-uri=http://localhost:${wiremock.server.port}"
})
class JwtTokenIntegrationTest extends BaseIntegrationTest {
    
    @RegisterExtension
    static WireMockExtension wireMock = WireMockExtension.newInstance()
        .options(wireMockConfig().port(0))
        .build();
    
    @Autowired
    private OAuth2TokenCustomizer<JwtEncodingContext> tokenCustomizer;
    
    @Test
    void testJwtTokenWithWorkspaceClaims() {
        // Mock workspace service response
        wireMock.stubFor(get(urlEqualTo("/internal/users/test-user/workspace-permissions"))
            .willReturn(aResponse()
                .withStatus(200)
                .withHeader("Content-Type", "application/json")
                .withBody("""
                    [{
                        "userId": "test-user",
                        "workspaceId": "workspace-1",
                        "workspaceName": "Test Workspace",
                        "permissions": ["case:read", "case:write"],
                        "isActive": true
                    }]
                """)));
        
        // Create JWT encoding context
        JwtEncodingContext context = createMockJwtContext();
        
        // Customize token
        tokenCustomizer.customize(context);
        
        // Verify workspace claims
        Map<String, Object> claims = context.getClaims().build().getClaims();
        
        assertThat(claims).containsKey("workspaces");
        assertThat(claims).containsKey("active_workspace");
        assertThat(claims.get("active_workspace")).isEqualTo("workspace-1");
        
        @SuppressWarnings("unchecked")
        Map<String, Object> workspaces = (Map<String, Object>) claims.get("workspaces");
        assertThat(workspaces).containsKey("workspace-1");
    }
}
```

### 4. API Contract Tests

#### Workspace API Contract Test
```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class WorkspaceApiContractTest extends BaseIntegrationTest {
    
    @Autowired
    private TestRestTemplate restTemplate;
    
    @Test
    void testPermissionCheckApiContract() {
        // Setup test data
        String workspaceId = "test-workspace";
        String userId = "test-user";
        
        PermissionCheckRequest request = PermissionCheckRequest.builder()
            .permissionCode("case:read")
            .build();
        
        // Make API call
        ResponseEntity<Boolean> response = restTemplate.postForEntity(
            "/workspaces/{workspaceId}/permissions/{userId}/check",
            request,
            Boolean.class,
            workspaceId,
            userId
        );
        
        // Verify response
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotNull();
    }
    
    @Test
    void testUserPermissionsApiContract() {
        String workspaceId = "test-workspace";
        String userId = "test-user";
        
        ResponseEntity<UserWorkspacePermissions> response = restTemplate.getForEntity(
            "/workspaces/{workspaceId}/permissions/{userId}",
            UserWorkspacePermissions.class,
            workspaceId,
            userId
        );
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        
        UserWorkspacePermissions permissions = response.getBody();
        assertThat(permissions).isNotNull();
        assertThat(permissions.getUserId()).isEqualTo(userId);
        assertThat(permissions.getWorkspaceId()).isEqualTo(workspaceId);
    }
}
```

## End-to-End Testing Strategy

### 1. Test Scenarios

#### Scenario 1: Complete User Journey
```gherkin
Feature: Multi-tenant Legal Case Management
  
  Scenario: User creates and manages cases across workspaces
    Given user "lawyer1@firm.com" is authenticated
    And user belongs to workspaces "firm-a" and "firm-b"
    And user has "case:write" permission in "firm-a"
    And user has "case:read" permission in "firm-b"
    
    When user switches to workspace "firm-a"
    And user creates a legal case
    Then case should be created successfully
    And case should be isolated to "firm-a" workspace
    
    When user switches to workspace "firm-b"
    And user tries to create a legal case
    Then request should be denied with 403 Forbidden
    
    When user tries to view cases from "firm-a"
    Then user should see no cases (workspace isolation)
```

#### Scenario 2: Permission Inheritance and Role Changes
```gherkin
Feature: Dynamic Permission Management
  
  Scenario: Role-based permission changes
    Given user "associate@firm.com" has role "Junior Associate"
    And "Junior Associate" role has permissions ["case:read"]
    And user is in workspace "law-firm"
    
    When user tries to delete a case
    Then request should be denied
    
    When admin promotes user to "Senior Associate" role
    And "Senior Associate" role has permissions ["case:read", "case:write", "case:delete"]
    And user tries to delete a case
    Then case should be deleted successfully
```

### 2. E2E Test Implementation

#### Multi-Service E2E Test
```java
@SpringBootTest
@TestMethodOrder(OrderAnnotation.class)
class MultiTenantE2ETest {
    
    @Autowired
    private TestRestTemplate restTemplate;
    
    @MockBean
    private WorkspaceClient workspaceClient;
    
    private String jwtToken;
    private String workspaceId = "test-workspace";
    private String userId = "test-user";
    
    @Test
    @Order(1)
    void setupTestEnvironment() {
        // Create workspace and user setup
        setupWorkspaceWithUser();
        jwtToken = generateTestJwtToken();
    }
    
    @Test
    @Order(2)
    void testWorkspaceAccessControl() {
        // Test workspace validation
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(jwtToken);
        headers.set("X-Workspace-Id", workspaceId);
        
        HttpEntity<Void> request = new HttpEntity<>(headers);
        
        ResponseEntity<String> response = restTemplate.exchange(
            "/api/cases",
            HttpMethod.GET,
            request,
            String.class
        );
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }
    
    @Test
    @Order(3)
    void testCrossWorkspaceIsolation() {
        // Create case in workspace A
        String caseId = createCaseInWorkspace("workspace-a");
        
        // Try to access from workspace B
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(jwtToken);
        headers.set("X-Workspace-Id", "workspace-b");
        
        HttpEntity<Void> request = new HttpEntity<>(headers);
        
        ResponseEntity<String> response = restTemplate.exchange(
            "/api/cases/" + caseId,
            HttpMethod.GET,
            request,
            String.class
        );
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }
    
    @Test
    @Order(4)
    void testPermissionAnnotationValidation() {
        // Test method with @RequirePermission annotation
        when(workspaceClient.hasPermission(userId, workspaceId, "case:delete"))
            .thenReturn(false);
        
        HttpHeaders headers = createAuthHeaders();
        HttpEntity<Void> request = new HttpEntity<>(headers);
        
        ResponseEntity<String> response = restTemplate.exchange(
            "/api/cases/test-case-id",
            HttpMethod.DELETE,
            request,
            String.class
        );
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }
}
```

## Performance and Load Testing

### 1. Permission Check Performance Test
```java
@Test
void testPermissionCheckPerformance() {
    StopWatch stopWatch = new StopWatch();
    
    // Test 1000 permission checks
    stopWatch.start();
    for (int i = 0; i < 1000; i++) {
        workspaceSecurityService.hasPermission("case:read");
    }
    stopWatch.stop();
    
    // Should complete within reasonable time (e.g., < 1 second)
    assertThat(stopWatch.getTotalTimeMillis()).isLessThan(1000);
}
```

### 2. JWT Token Generation Load Test
```java
@Test
void testJwtTokenGenerationLoad() {
    ExecutorService executor = Executors.newFixedThreadPool(10);
    List<CompletableFuture<Void>> futures = new ArrayList<>();
    
    for (int i = 0; i < 100; i++) {
        CompletableFuture<Void> future = CompletableFuture.runAsync(() -> {
            // Generate JWT token with workspace claims
            JwtEncodingContext context = createMockJwtContext();
            tokenCustomizer.customize(context);
            
            // Verify token contains workspace claims
            Map<String, Object> claims = context.getClaims().build().getClaims();
            assertThat(claims).containsKey("workspaces");
        }, executor);
        
        futures.add(future);
    }
    
    CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();
    executor.shutdown();
}
```

## Test Data Management

### 1. Test Data Builder Pattern
```java
public class TestDataBuilder {
    
    public static WorkspaceBuilder workspace() {
        return new WorkspaceBuilder();
    }
    
    public static class WorkspaceBuilder {
        private String name = "Test Workspace";
        private String domain = "test-domain";
        
        public WorkspaceBuilder withName(String name) {
            this.name = name;
            return this;
        }
        
        public WorkspaceBuilder withDomain(String domain) {
            this.domain = domain;
            return this;
        }
        
        public Workspace build() {
            Workspace workspace = new Workspace();
            workspace.setName(name);
            workspace.setDomain(domain);
            workspace.setCreatedAt(LocalDateTime.now());
            workspace.setUpdatedAt(LocalDateTime.now());
            return workspace;
        }
    }
}
```

### 2. Database Test Data Setup
```sql
-- test-data.sql
INSERT INTO workspace.workspaces (id, name, domain, created_at, updated_at) VALUES
('workspace-1', 'Test Workspace 1', 'test1', NOW(), NOW()),
('workspace-2', 'Test Workspace 2', 'test2', NOW(), NOW());

INSERT INTO workspace.permissions (code, name, service, resource, action, is_enabled) VALUES
('case:read', 'Read Cases', 'legal-case', 'case', 'read', true),
('case:write', 'Write Cases', 'legal-case', 'case', 'write', true),
('case:delete', 'Delete Cases', 'legal-case', 'case', 'delete', true);

INSERT INTO workspace.workspace_members (user_id, workspace_id, role, is_active, created_at, updated_at) VALUES
('test-user-1', 'workspace-1', 'MEMBER', true, NOW(), NOW()),
('test-user-1', 'workspace-2', 'MEMBER', true, NOW(), NOW());
```

## Continuous Integration Pipeline

### 1. Test Execution Pipeline
```yaml
# .github/workflows/integration-tests.yml
name: Integration Tests

on:
  pull_request:
    branches: [ main ]
  push:
    branches: [ main ]

jobs:
  integration-tests:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up JDK 21
      uses: actions/setup-java@v4
      with:
        java-version: '21'
        distribution: 'temurin'
    
    - name: Run Integration Tests
      run: |
        ./mvnw clean verify -P integration-test
    
    - name: Upload Test Reports
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: test-reports
        path: |
          **/target/surefire-reports/
          **/target/failsafe-reports/
```

## Test Reporting and Metrics

### 1. Test Coverage Requirements
- Unit Tests: > 80% line coverage
- Integration Tests: > 70% scenario coverage
- E2E Tests: > 90% critical path coverage

### 2. Test Execution Metrics
- Permission check response time < 50ms
- JWT token generation < 100ms
- Cross-service communication < 200ms

This comprehensive integration testing strategy ensures robust validation of the multi-tenant RBAC architecture across all service boundaries and user interactions.