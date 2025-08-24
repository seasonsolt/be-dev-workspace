# Multi-Tenant RBAC Integration Test Setup Guide

## Maven Configuration

Add the following to your `pom.xml` files to support integration testing:

### be-legal-case/pom.xml

```xml
<!-- Add these dependencies to the existing dependencies section -->
<dependencies>
    <!-- Existing dependencies... -->
    
    <!-- Test dependencies -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-test</artifactId>
        <scope>test</scope>
    </dependency>
    
    <dependency>
        <groupId>org.springframework.security</groupId>
        <artifactId>spring-security-test</artifactId>
        <scope>test</scope>
    </dependency>
    
    <!-- Testcontainers -->
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>junit-jupiter</artifactId>
        <scope>test</scope>
    </dependency>
    
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>postgresql</artifactId>
        <scope>test</scope>
    </dependency>
    
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>testcontainers</artifactId>
        <scope>test</scope>
    </dependency>
    
    <!-- WireMock for service mocking -->
    <dependency>
        <groupId>com.github.tomakehurst</groupId>
        <artifactId>wiremock-jre8</artifactId>
        <scope>test</scope>
    </dependency>
    
    <!-- AssertJ for better assertions -->
    <dependency>
        <groupId>org.assertj</groupId>
        <artifactId>assertj-core</artifactId>
        <scope>test</scope>
    </dependency>
</dependencies>

<!-- Add these profiles and plugins -->
<profiles>
    <profile>
        <id>integration-test</id>
        <properties>
            <skip.integration.tests>false</skip.integration.tests>
            <skip.unit.tests>false</skip.unit.tests>
        </properties>
    </profile>
    
    <profile>
        <id>unit-test</id>
        <activation>
            <activeByDefault>true</activeByDefault>
        </activation>
        <properties>
            <skip.integration.tests>true</skip.integration.tests>
            <skip.unit.tests>false</skip.unit.tests>
        </properties>
    </profile>
</profiles>

<build>
    <plugins>
        <!-- Surefire Plugin for Unit Tests -->
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-surefire-plugin</artifactId>
            <version>3.0.0-M9</version>
            <configuration>
                <skipTests>${skip.unit.tests}</skipTests>
                <excludes>
                    <exclude>**/*IntegrationTest.java</exclude>
                    <exclude>**/*PerformanceTest.java</exclude>
                </excludes>
            </configuration>
        </plugin>
        
        <!-- Failsafe Plugin for Integration Tests -->
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-failsafe-plugin</artifactId>
            <version>3.0.0-M9</version>
            <configuration>
                <skipTests>${skip.integration.tests}</skipTests>
                <includes>
                    <include>**/*IntegrationTest.java</include>
                    <include>**/*PerformanceTest.java</include>
                </includes>
                <systemPropertyVariables>
                    <spring.profiles.active>integration-test</spring.profiles.active>
                </systemPropertyVariables>
            </configuration>
            <executions>
                <execution>
                    <goals>
                        <goal>integration-test</goal>
                        <goal>verify</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
        
        <!-- JaCoCo for Test Coverage -->
        <plugin>
            <groupId>org.jacoco</groupId>
            <artifactId>jacoco-maven-plugin</artifactId>
            <version>0.8.8</version>
            <executions>
                <execution>
                    <goals>
                        <goal>prepare-agent</goal>
                    </goals>
                </execution>
                <execution>
                    <id>report</id>
                    <phase>test</phase>
                    <goals>
                        <goal>report</goal>
                    </goals>
                </execution>
                <execution>
                    <id>integration-test-coverage</id>
                    <goals>
                        <goal>prepare-agent-integration</goal>
                    </goals>
                </execution>
                <execution>
                    <id>integration-test-report</id>
                    <phase>post-integration-test</phase>
                    <goals>
                        <goal>report-integration</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```

## Running Tests

### Command Line

```bash
# Run only unit tests (default)
mvn test

# Run only integration tests
mvn verify -P integration-test -DskipUnitTests=true

# Run all tests
mvn verify -P integration-test

# Run specific integration test
mvn verify -P integration-test -Dit.test=MultiTenantRbacIntegrationTest

# Run performance tests
mvn verify -P integration-test -Dit.test=*PerformanceTest

# Generate coverage report
mvn clean verify -P integration-test jacoco:report
```

### IDE Configuration

#### IntelliJ IDEA

1. **Create Test Configuration**
   - Run → Edit Configurations
   - Add New → JUnit
   - Name: "Integration Tests"
   - Test kind: "All in package"
   - Package: `com.ginkgooai.legalcase.integration`
   - VM options: `-Dspring.profiles.active=integration-test`
   - Environment variables: Add any required test environment variables

2. **Docker Integration** (Optional)
   - Install Docker plugin
   - Create docker-compose.test.yml in project root
   - Configure test containers to use Docker services

#### VS Code

1. **Java Test Runner Configuration**
   ```json
   {
     "java.test.config": [
       {
         "name": "integration-test",
         "workingDirectory": "${workspaceFolder}",
         "vmArgs": ["-Dspring.profiles.active=integration-test"],
         "env": {
           "SPRING_PROFILES_ACTIVE": "integration-test"
         }
       }
     ]
   }
   ```

## Test Environment Setup

### Docker Compose for Local Testing

```yaml
# docker-compose.test.yml
version: '3.8'
services:
  postgres-test:
    image: postgres:15-alpine
    container_name: postgres-test
    environment:
      POSTGRES_DB: test_db
      POSTGRES_USER: test_user
      POSTGRES_PASSWORD: test_pass
    ports:
      - "5433:5432"
    volumes:
      - ./test-data:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U test_user -d test_db"]
      interval: 10s
      timeout: 5s
      retries: 5
  
  redis-test:
    image: redis:7-alpine
    container_name: redis-test
    ports:
      - "6380:6379"
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
  
  wiremock:
    image: wiremock/wiremock:2.35.0
    container_name: wiremock-test
    ports:
      - "9090:8080"
    volumes:
      - ./src/test/resources/wiremock:/home/wiremock
    command: --global-response-templating --verbose

networks:
  default:
    name: ginkgoo-test-network
```

### Start Test Environment

```bash
# Start test environment
docker-compose -f docker-compose.test.yml up -d

# Wait for services to be ready
docker-compose -f docker-compose.test.yml ps

# Run tests
mvn verify -P integration-test

# Stop test environment
docker-compose -f docker-compose.test.yml down
```

## Test Data Management

### Database Test Data

Test data is automatically loaded from `src/test/resources/test-data.sql` during test container startup.

### WireMock Stubs

Create stub files in `src/test/resources/wiremock/mappings/`:

```json
{
  "request": {
    "method": "GET",
    "urlPattern": "/workspaces/.*/permissions/.*"
  },
  "response": {
    "status": 200,
    "headers": {
      "Content-Type": "application/json"
    },
    "bodyFileName": "workspace-permissions-response.json"
  }
}
```

### Test Profiles

Different test profiles for different scenarios:

- `integration-test`: Full integration testing with containers
- `integration-test-fast`: In-memory databases for faster testing
- `performance-test`: Performance testing configuration

## Continuous Integration

### GitHub Actions

```yaml
# .github/workflows/integration-tests.yml
name: Integration Tests

on:
  pull_request:
    branches: [ main, develop ]
  push:
    branches: [ main, develop ]

jobs:
  integration-tests:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_USER: test_user
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5433:5432
      
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6380:6379
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up JDK 21
      uses: actions/setup-java@v4
      with:
        java-version: '21'
        distribution: 'temurin'
    
    - name: Cache Maven dependencies
      uses: actions/cache@v3
      with:
        path: ~/.m2
        key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
    
    - name: Run Integration Tests
      run: |
        cd be-legal-case
        mvn clean verify -P integration-test
    
    - name: Upload Test Reports
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: test-reports
        path: |
          be-legal-case/target/surefire-reports/
          be-legal-case/target/failsafe-reports/
          be-legal-case/target/site/jacoco/
    
    - name: Upload Coverage to Codecov
      uses: codecov/codecov-action@v3
      if: always()
      with:
        files: be-legal-case/target/site/jacoco/jacoco.xml
        flags: integration-tests
```

## Test Monitoring and Reporting

### Test Coverage Requirements

- **Unit Tests**: Minimum 80% line coverage
- **Integration Tests**: Minimum 70% scenario coverage
- **Critical Path**: 100% coverage for security and permission logic

### Performance Benchmarks

- Permission check: < 50ms average
- API response time: < 1 second 95th percentile
- Concurrent throughput: > 100 requests/second
- Memory usage: < 100MB increase during extended operations

### Test Reports

Generated test reports are available at:
- Unit test results: `target/surefire-reports/`
- Integration test results: `target/failsafe-reports/`
- Coverage report: `target/site/jacoco/index.html`
- Performance metrics: Console output during test execution

## Troubleshooting

### Common Issues

1. **Test containers not starting**
   - Check Docker is running
   - Verify port availability (5433, 6380, 9090)
   - Increase container startup timeout

2. **Permission tests failing**
   - Verify workspace client mocks are properly configured
   - Check JWT token generation in tests
   - Ensure test data is loaded correctly

3. **Performance tests failing**
   - Adjust performance thresholds for your environment
   - Consider system resources during testing
   - Run performance tests in isolation

4. **Database connection issues**
   - Verify PostgreSQL test container is healthy
   - Check database connection URL and credentials
   - Ensure test schema exists

### Debug Mode

Run tests with debug logging:

```bash
mvn verify -P integration-test -Dlogging.level.com.ginkgooai.legalcase=DEBUG -Dspring.jpa.show-sql=true
```

This comprehensive setup ensures thorough testing of the multi-tenant RBAC architecture across all service boundaries and interaction patterns.