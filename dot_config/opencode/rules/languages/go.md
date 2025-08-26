# Go Rules

## Style and Formatting
- Use gofmt for consistent code formatting
- Use golint and go vet for code quality checks
- Follow effective Go guidelines and conventions
- Use camelCase for exported names, lowercase for unexported
- Keep package names short, concise, and lowercase

## Code Organization
- Organize code into packages with clear responsibilities
- Keep package interfaces small and focused
- Use internal packages for implementation details
- Group related functionality together
- Use meaningful names for packages, types, and functions

## Error Handling
- Handle errors explicitly, don't ignore them
- Return errors as the last return value
- Use custom error types when additional context is needed
- Wrap errors with context using fmt.Errorf and %w verb
- Check for specific error types when necessary

## Concurrency
- Use goroutines for concurrent operations
- Communicate through channels, don't share memory
- Use select statements for non-blocking channel operations
- Prefer channels over shared variables with mutexes
- Use sync.WaitGroup for coordinating goroutines

## Performance Considerations
- Use appropriate data structures (slice vs array, map vs slice)
- Avoid unnecessary memory allocations
- Use sync.Pool for frequently allocated objects
- Profile before optimizing (go tool pprof)
- Use benchmarks to measure performance improvements

## Testing
- Write comprehensive tests using built-in testing package
- Use table-driven tests for multiple test cases
- Write benchmarks for performance-critical code
- Use testify or similar packages for assertions when helpful
- Test both success and failure paths

## Documentation
- Write clear godoc comments for exported functions and types
- Use complete sentences in documentation comments
- Provide examples in documentation when helpful
- Use go doc to generate and review documentation
- Document expected behavior and edge cases

## Dependency Management
- Use go mod for dependency management
- Keep go.mod file clean and minimal
- Use semantic versioning for module releases
- Pin dependency versions for reproducible builds
- Run go mod tidy regularly to clean up dependencies

## Build and Deployment
- Use go build flags appropriately (-ldflags, -tags)
- Cross-compile for different platforms when needed
- Use go generate for code generation tasks
- Set up proper CI/CD with go test, go vet, golint
- Use Docker for consistent deployment environments

## Best Practices
- Keep interfaces small and focused
- Use composition over inheritance
- Prefer explicit error handling over panics
- Use context.Context for cancellation and timeouts
- Implement Stringer interface for custom types when appropriate

## Modern Go Features
- Use generics (Go 1.18+) for type-safe data structures
- Leverage embed directive for static file embedding
- Use go:linkname sparingly and only when necessary
- Take advantage of module workspaces for multi-module projects
- Use fuzzing for finding edge cases in functions

## Security Considerations
- Validate inputs thoroughly
- Use crypto/rand for random number generation
- Implement proper authentication and authorization
- Use HTTPS for all network communications
- Be mindful of timing attacks in cryptographic operations