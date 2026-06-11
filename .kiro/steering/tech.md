# Tech Stack

## Language & Runtime
- Java 17 (minimum)
- Spring Boot 4.0.3

## Frameworks & Libraries
- **Web**: Spring MVC (`spring-boot-starter-webmvc`)
- **Templating**: Thymeleaf (`spring-boot-starter-thymeleaf`)
- **Persistence**: Spring Data JPA + Hibernate (`spring-boot-starter-data-jpa`)
- **Validation**: Jakarta Bean Validation (`spring-boot-starter-validation`)
- **Caching**: Spring Cache + Caffeine
- **Monitoring**: Spring Boot Actuator
- **Frontend**: Bootstrap 5.3, Font-Awesome 4.7 (served via WebJars)

## Databases
- **Default (dev)**: H2 in-memory — no setup required
- **MySQL**: activate with `spring.profiles.active=mysql`
- **PostgreSQL**: activate with `spring.profiles.active=postgres`

## Build Systems
Both Maven and Gradle are fully supported and kept in sync.

### Maven (primary)
```bash
./mvnw spring-boot:run          # Run the app
./mvnw test                     # Run all tests
./mvnw package                  # Build JAR
./mvnw package -P css           # Recompile CSS from SCSS (needed after scss changes)
./mvnw spring-boot:build-image  # Build OCI container image
```

### Gradle
```bash
./gradlew bootRun   # Run the app
./gradlew test      # Run all tests
./gradlew build     # Build JAR
```

## Code Quality
- **Formatter**: `io.spring.javaformat` — enforced at build time via `validate` phase; run `./mvnw spring-javaformat:apply` to auto-format
- **Checkstyle**: `nohttp-checkstyle` — ensures no plain HTTP URLs in source; config in `src/checkstyle/`
- **Coverage**: JaCoCo — report generated at `target/site/jacoco/`

## Testing
- **Unit/slice tests**: JUnit 5 + Spring Boot test slices (`@WebMvcTest`, `@DataJpaTest`)
- **Integration tests**: `PetClinicIntegrationTests` (H2), `MySqlIntegrationTests` (Testcontainers), `PostgresIntegrationTests` (Docker Compose)
- Test applications can be run as standalone `main()` methods for fast IDE feedback

## CI/CD
- GitHub Actions workflows in `.github/workflows/` for Maven and Gradle builds
- Jenkins pipeline in `jenkins-cicd-poc/Jenkinsfile` for POC CI/CD setup
- Kubernetes manifests in `k8s/` for deployment

## GraalVM Native Image
- Supported via `org.graalvm.buildtools.native` plugin
- Runtime hints registered in `PetClinicRuntimeHints`
