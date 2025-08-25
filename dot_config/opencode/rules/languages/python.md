# Python Rules

## Style and Formatting
- Use Black for code formatting and consistent style
- Follow PEP 8 guidelines for style conventions
- Use 4 spaces for indentation, never tabs
- Keep line length under 88 characters (Black default)
- Use snake_case for variables and functions, PascalCase for classes

## Code Organization
- Structure projects with clear module hierarchy
- Use __init__.py files to define package interfaces
- Follow single responsibility principle for classes and functions
- Use type hints for function parameters and return values
- Organize imports: standard library, third-party, local imports

## Python Idioms
- Use list/dict/set comprehensions when appropriate
- Leverage context managers (with statements) for resource management
- Use enumerate() instead of range(len()) for indexing
- Prefer f-strings for string formatting
- Use pathlib for file path operations

## Error Handling
- Use specific exception types rather than bare except clauses
- Create custom exception classes for domain-specific errors
- Use try/except/else/finally appropriately
- Validate inputs early and fail fast
- Log exceptions with appropriate detail

## Performance Considerations
- Use appropriate data structures (set for membership tests, deque for queues)
- Avoid premature optimization, profile first
- Use generators for memory-efficient iteration over large datasets
- Consider using dataclasses or namedtuples for simple data containers
- Leverage built-in functions and standard library modules

## Testing
- Write comprehensive tests using pytest or unittest
- Use fixtures for test setup and teardown
- Mock external dependencies and I/O operations
- Test both happy path and error conditions
- Maintain high test coverage but focus on critical paths

## Dependencies and Virtual Environments
- Use virtual environments for project isolation
- Pin dependency versions in requirements.txt or pyproject.toml
- Use tools like pip-tools for dependency management
- Regularly update dependencies and check for security issues
- Document installation and setup procedures

## Documentation
- Use docstrings for modules, classes, and functions
- Follow Google or NumPy docstring conventions
- Generate documentation using Sphinx when appropriate
- Include type information in docstrings
- Provide usage examples for complex functions

## Modern Python Features
- Use dataclasses for simple data containers
- Leverage async/await for I/O-bound operations
- Use pattern matching (Python 3.10+) where appropriate
- Take advantage of union types and Optional from typing
- Use positional-only and keyword-only parameters when beneficial