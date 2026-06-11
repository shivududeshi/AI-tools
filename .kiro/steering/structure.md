# Project Structure

## Root Layout

```
spring-petclinic/
├── src/
│   ├── main/
│   │   ├── java/         # Application source
│   │   ├── resources/    # Config, templates, static assets, DB scripts
│   │   └── scss/         # SCSS source (compiled to CSS via -P css profile)
│   └── test/
│       ├── java/         # Test source (mirrors main package structure)
│       └── jmeter/       # JMeter load test plans
├── k8s/                  # Kubernetes manifests (petclinic + db)
├── jenkins-cicd-poc/     # Jenkins CI/CD POC setup and Jenkinsfile
├── .github/workflows/    # GitHub Actions CI pipelines
├── .kiro/                # Kiro AI assistant config (steering, powers)
├── pom.xml               # Maven build descriptor (primary)
├── build.gradle          # Gradle build descriptor (kept in sync with Maven)
└── docker-compose.yml    # Docker Compose for MySQL/PostgreSQL dev databases
```

## Java Package Structure

Base package: `org.springframework.samples.petclinic`

```
petclinic/
├── model/        # Shared JPA base classes (BaseEntity, NamedEntity, Person)
├── owner/        # Owner, Pet, PetType, Visit domain + controllers + repositories
├── vet/          # Vet, Specialty domain + controller + repository
└── system/       # Cross-cutting: CacheConfiguration, error handling
```

### Package Conventions
- Each domain package is self-contained: entity, repository, controller, and validators all live together
- No service layer — controllers interact directly with Spring Data repositories
- Shared base entities only go in `model/`; domain-specific classes stay in their own package

## Key Source Files

| File | Purpose |
|------|---------|
| `PetClinicApplication.java` | Main entry point (`@SpringBootApplication`) |
| `PetClinicRuntimeHints.java` | GraalVM native image hints |
| `owner/OwnerRepository.java` | Spring Data JPA repo for owners |
| `vet/VetRepository.java` | Spring Data JPA repo for vets (cached) |
| `system/CacheConfiguration.java` | Caffeine cache setup |

## Resources Layout

```
src/main/resources/
├── application.properties          # Default config (H2)
├── application-mysql.properties    # MySQL profile overrides
├── application-postgres.properties # PostgreSQL profile overrides
├── db/
│   ├── h2/                         # H2 schema + seed data
│   ├── mysql/                      # MySQL schema + seed data
│   └── postgres/                   # PostgreSQL schema + seed data
├── messages/                       # i18n message bundles
├── static/resources/css/           # Compiled CSS (do not edit directly)
└── templates/                      # Thymeleaf HTML templates
    ├── owners/
    ├── pets/
    ├── vets/
    └── fragments/                  # Shared layout fragments
```

## Test Structure

Tests mirror the main package layout under `src/test/java/`. Key patterns:
- `*ControllerTests` — `@WebMvcTest` slice tests (no DB)
- `*Tests` / `ValidatorTests` — plain unit tests
- `ClinicServiceTests` — `@DataJpaTest` repository tests
- `PetClinicIntegrationTests` — full context with H2
- `MySqlIntegrationTests` — full context with Testcontainers MySQL
- `PostgresIntegrationTests` — full context with Docker Compose PostgreSQL

## Architecture Patterns

- **No service layer**: controllers call repositories directly; add a service layer only if shared business logic emerges across controllers
- **Domain packages**: group all related classes (entity, repo, controller, validator) by domain, not by layer
- **Inheritance hierarchy**: `BaseEntity` → `NamedEntity` or `Person` → domain entity
- **Bean Validation on entities**: use Jakarta annotations (`@NotBlank`, `@Size`, `@Pattern`) on entity fields; validate in controllers with `@Valid`
- **Spring Data JPA repositories**: extend `JpaRepository` or `Repository`; no custom `EntityManager` usage
- **Thymeleaf templates**: server-side rendered; no REST API or SPA frontend
