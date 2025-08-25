# Security Rules

## Authentication & Credentials
- Never hardcode API keys, passwords, or tokens in source code
- Use environment variables or secure credential management systems
- Implement proper authentication and authorization checks
- Use secure random number generation for tokens and passwords

## Input Validation
- Validate all user inputs before processing
- Sanitize data before database operations (prevent SQL injection)
- Escape data before rendering in web contexts (prevent XSS)
- Validate file paths to prevent directory traversal attacks

## Sensitive Data Handling
- Never log sensitive information (passwords, tokens, PII)
- Use secure communication protocols (HTTPS, TLS)
- Implement proper session management
- Follow data minimization principles

## Dependencies & Supply Chain
- Regularly update dependencies to patch security vulnerabilities
- Use dependency scanning tools to identify known vulnerabilities
- Verify package integrity and authenticity
- Avoid dependencies with known security issues

## Error Handling
- Don't expose sensitive information in error messages
- Log security events appropriately
- Implement proper exception handling
- Use fail-secure defaults