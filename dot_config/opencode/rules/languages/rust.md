# Rust Rules

## Ownership and Memory Management
- Understand and leverage Rust's ownership system
- Use borrowing (&) instead of moving when possible
- Prefer immutable references over mutable ones
- Use lifetimes explicitly when the compiler requires them
- Avoid unnecessary cloning; use references when appropriate

## Style and Formatting
- Use rustfmt for consistent code formatting
- Use Clippy for linting and best practice suggestions
- Use snake_case for variables, functions, and modules
- Use PascalCase for types, traits, and enum variants
- Keep line length reasonable (usually 100 characters)

## Error Handling
- Use Result<T, E> for operations that can fail
- Use Option<T> for values that may be absent
- Prefer ? operator over explicit match for error propagation
- Create custom error types using thiserror or similar crates
- Handle errors at appropriate levels, don't ignore them

## Code Organization
- Use modules to organize code logically
- Keep functions small and focused on single tasks
- Use traits for shared behavior and abstraction
- Implement Display and Debug traits for custom types
- Use proper visibility modifiers (pub, pub(crate), etc.)

## Performance and Efficiency
- Prefer iterators over index-based loops
- Use zero-cost abstractions when possible
- Avoid unnecessary allocations and String creation
- Use appropriate data structures (Vec, HashMap, BTreeMap, etc.)
- Profile before optimizing, but be mindful of algorithmic complexity

## Testing
- Write comprehensive unit tests using built-in test framework
- Use integration tests for testing public APIs
- Write property-based tests for complex logic
- Use cargo test for running all tests
- Test both success and failure cases

## Dependencies and Crates
- Keep Cargo.toml organized with clear feature flags
- Use semantic versioning appropriately
- Prefer well-maintained crates with active communities
- Document why specific crates are chosen
- Use cargo audit to check for security vulnerabilities

## Concurrency and Parallelism
- Use channels for communication between threads
- Prefer higher-level abstractions (Rayon) for data parallelism
- Use Arc<Mutex<T>> or Arc<RwLock<T>> for shared state
- Be mindful of Send and Sync trait bounds
- Use async/await for I/O-bound operations

## Documentation
- Write comprehensive rustdoc comments for public APIs
- Use examples in documentation (they're tested!)
- Document panicking conditions and safety requirements
- Use appropriate rustdoc attributes (#[doc], etc.)
- Generate and review documentation regularly

## Safety and Best Practices
- Minimize use of unsafe code; justify when necessary
- Use #[must_use] attribute for types that should not be ignored
- Implement proper Debug formatting for easier debugging
- Use derive macros for common traits when appropriate
- Follow Rust API design guidelines

## Cargo and Build System
- Use workspaces for multi-crate projects
- Configure appropriate optimization levels
- Use feature flags to make code modular
- Set up proper CI/CD with cargo fmt, clippy, and tests
- Use cargo doc to generate and publish documentation

## Modern Rust Features
- Use const generics for compile-time parameters
- Leverage pattern matching with match expressions
- Use if let and while let for ergonomic Option/Result handling
- Take advantage of closure syntax and functional programming
- Use procedural macros when code generation is beneficial