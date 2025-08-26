# TypeScript Rules

## Type System Usage
- Enable strict mode in tsconfig.json for better type safety
- Use explicit type annotations for function parameters and return types
- Leverage union types and intersection types appropriately
- Use generic types for reusable components and functions
- Prefer interfaces over type aliases for object shapes

## Style and Formatting
- Use Prettier for consistent code formatting
- Use ESLint with TypeScript rules for code quality
- Use 2 spaces for indentation, no tabs
- Use PascalCase for types, interfaces, and classes
- Use camelCase for variables, functions, and properties

## Modern TypeScript Features
- Use optional chaining (?.) and nullish coalescing (??) operators
- Leverage template literal types for string manipulation
- Use mapped types and conditional types for advanced type transformations
- Take advantage of utility types (Partial, Pick, Omit, etc.)
- Use const assertions for immutable data structures

## Code Organization
- Organize code with barrel exports (index.ts files)
- Use namespaces sparingly, prefer ES6 modules
- Group related types and interfaces together
- Use path mapping in tsconfig.json for cleaner imports
- Separate type definitions from implementation when appropriate

## Error Handling
- Use discriminated unions for error handling patterns
- Create custom error types with proper inheritance
- Use Result or Either types for functional error handling
- Leverage TypeScript's control flow analysis
- Handle both sync and async errors consistently

## Type Definitions
- Write comprehensive JSDoc comments for public APIs
- Use @deprecated tags for deprecated functions
- Document generic type parameters clearly
- Provide examples in JSDoc for complex types
- Export types that consumers might need

## Configuration
- Configure strict compiler options in tsconfig.json
- Use separate configs for different environments (dev, prod, test)
- Set up path mapping for clean imports
- Configure module resolution appropriately
- Use incremental compilation for faster builds

## Testing
- Use type-safe testing frameworks (Jest with @types/jest)
- Write tests that verify both runtime behavior and types
- Use type assertions sparingly and only when necessary
- Test edge cases with union types and optional properties
- Mock external dependencies with proper typing

## React/Frontend Specific (when applicable)
- Use functional components with proper prop types
- Leverage React.FC or explicit return types for components
- Use proper event handler types (React.MouseEvent, etc.)
- Define component props with interfaces
- Use generic components for reusable UI elements

## Node.js/Backend Specific (when applicable)
- Use @types packages for Node.js and third-party libraries
- Type HTTP request/response objects properly
- Use proper types for database models and queries
- Implement typed environment variable validation
- Use dependency injection with proper typing

## Performance Considerations
- Use type-only imports when importing only types
- Avoid any type except in migration scenarios
- Use tree-shaking friendly import patterns
- Configure TypeScript for optimal bundle size
- Use lazy loading with proper type preservation