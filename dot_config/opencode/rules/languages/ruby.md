# Ruby Rules

## Style and Formatting
- Use RuboCop for linting and style enforcement
- Follow the Ruby Style Guide conventions
- Use 2 spaces for indentation, no tabs
- Keep line length under 120 characters
- Use snake_case for variables and methods, PascalCase for classes

## Code Organization
- Follow Rails conventions for file structure when applicable
- Use modules for namespacing and mixins
- Keep classes focused on single responsibility
- Extract complex logic into service objects or concerns
- Use descriptive method and variable names

## Ruby Idioms
- Prefer implicit returns over explicit return statements
- Use blocks and yield effectively
- Leverage Ruby's enumerable methods (map, select, reduce, etc.)
- Use symbols for keys and identifiers
- Prefer string interpolation over concatenation

## Error Handling
- Use specific exception classes rather than StandardError
- Handle exceptions at appropriate levels
- Use ensure blocks for cleanup when necessary
- Validate inputs and fail fast with clear error messages
- Document expected exceptions in method comments

## Performance Considerations
- Use appropriate data structures (Hash for lookups, Array for sequences)
- Avoid creating unnecessary objects in loops
- Use lazy evaluation when working with large datasets
- Consider memory usage with large collections
- Profile code before optimizing

## Testing
- Write comprehensive test suites using RSpec or Minitest
- Follow TDD/BDD practices when appropriate
- Use factories for test data (FactoryBot)
- Mock external dependencies in unit tests
- Test both happy path and edge cases

## Dependencies and Gems
- Keep Gemfile organized and commented
- Use specific version constraints for critical gems
- Regularly update gems and check for security vulnerabilities
- Prefer well-maintained gems with active communities
- Document gem choices and alternatives considered

## Rails-Specific Rules (when applicable)
- Follow RESTful routing conventions
- Use strong parameters for mass assignment protection
- Keep controllers thin, models fat (within reason)
- Use concerns for shared behavior
- Implement proper database migrations with rollback support
- Use Rails generators appropriately
- Follow Rails naming conventions for files and classes