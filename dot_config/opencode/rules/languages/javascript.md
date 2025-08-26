# JavaScript Rules

## Style and Formatting
- Use Prettier for consistent code formatting
- Use ESLint for linting and code quality checks
- Use 2 spaces for indentation, no tabs
- Use single quotes for strings unless interpolation is needed
- Use camelCase for variables and functions, PascalCase for classes

## Modern JavaScript (ES6+)
- Use const and let instead of var
- Prefer arrow functions for callbacks and short functions
- Use template literals for string interpolation
- Destructure objects and arrays when appropriate
- Use spread operator for array/object operations

## Code Organization
- Use ES6 modules (import/export) for code organization
- Keep functions small and focused on single tasks
- Group related functionality into modules
- Use meaningful names for variables, functions, and files
- Organize imports at the top of files

## Asynchronous Programming
- Use async/await instead of callbacks or .then() chains
- Handle errors properly with try/catch blocks
- Use Promise.all() for concurrent operations
- Avoid callback hell with proper async patterns
- Handle race conditions and timing issues

## Error Handling
- Use try/catch blocks for async operations
- Create custom Error classes for specific error types
- Validate inputs and fail fast with clear messages
- Log errors appropriately without exposing sensitive data
- Use error boundaries in React applications

## Performance Considerations
- Avoid creating functions in render loops
- Use appropriate data structures (Map, Set, WeakMap, WeakSet)
- Minimize DOM manipulation and use virtual DOM when possible
- Debounce/throttle expensive operations
- Use lazy loading for large resources

## Testing
- Write unit tests using Jest, Mocha, or similar frameworks
- Test both happy path and error conditions
- Mock external dependencies and APIs
- Use testing libraries like Testing Library for UI components
- Maintain good test coverage but focus on critical paths

## Browser Compatibility
- Use Babel for transpiling modern JavaScript features
- Test across different browsers and versions
- Use feature detection rather than browser detection
- Provide graceful degradation for unsupported features
- Use polyfills when necessary

## Security Considerations
- Validate and sanitize all user inputs
- Use HTTPS for all API requests
- Avoid eval() and similar dynamic code execution
- Implement proper CORS policies
- Store sensitive data securely (not in localStorage)

## Node.js Specific (when applicable)
- Use npm scripts for common tasks
- Keep package.json clean and well-documented
- Use environment variables for configuration
- Implement proper logging with appropriate levels
- Handle process signals gracefully