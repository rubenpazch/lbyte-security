# LByte Security API - curl Examples

This repository contains comprehensive curl examples for testing the LByte Security API authentication and user management endpoints.

## Quick Start

1. **Start the Rails Server**
   ```bash
   cd /path/to/lbyte-security
   bundle exec rails server -b 0.0.0.0 -p 3000
   ```

2. **Register a New User**
   ```bash
   curl -X POST http://localhost:3000/users \
     -H "Content-Type: application/json" \
     -d '{"user":{"email":"test@example.com","password":"password123","password_confirmation":"password123","username":"testuser"}}'
   ```

3. **Sign In to Get JWT Token**
   ```bash
   curl -i -X POST http://localhost:3000/users/sign_in \
     -H "Content-Type: application/json" \
     -d '{"user":{"email":"test@example.com","password":"password123"}}'
   ```

4. **Extract Token from Authorization Header and Use It**
   ```bash
   TOKEN="your_jwt_token_here"
   curl -H "Authorization: Bearer $TOKEN" http://localhost:3000/token/verify
   ```

## Available Documentation

### 📋 [User Registration Examples](./docs/api_registration_examples.md)
- Complete registration endpoint documentation
- Required and optional parameters
- Various registration scenarios
- Validation error examples
- Response format details

### 🔐 [Complete Authentication Workflow](./docs/complete_authentication_examples.md)
- End-to-end authentication examples
- Registration → Sign In → Token Usage → Sign Out
- Token verification and refresh
- Error handling scenarios
- Production considerations
- Security best practices

## API Endpoints

### Authentication
- `POST /users` - User registration
- `POST /users/sign_in` - User sign in (get JWT token)
- `DELETE /users/sign_out` - User sign out (invalidate token)

### Token Management
- `GET /token/verify` - Verify token validity (authenticated)
- `GET /token/info` - Get token information (public)
- `POST /token/refresh` - Refresh JWT token (authenticated)

## Example Responses

### Successful Registration
```json
{
  "status": {"code": 200, "message": "Signed up successfully."},
  "data": {
    "id": 42,
    "email": "test@example.com",
    "username": "testuser",
    "status": "active",
    "language": "en",
    "roles": ["User"],
    "created_at": "2025-08-17T01:35:16.899Z"
  }
}
```

### Successful Sign In
```json
{
  "message": "Logged in successfully.",
  "user": {
    "id": 42,
    "email": "test@example.com",
    "username": "testuser",
    "status": "active"
  }
}
```

**Note:** JWT token is returned in the `Authorization` header as `Bearer <token>`

### Token Verification
```json
{
  "valid": true,
  "user": {
    "id": 42,
    "email": "test@example.com",
    "username": "testuser",
    "roles": ["User"],
    "permissions": ["Read Users", "Create Expenses", "Update Expenses", "View Reports"]
  },
  "message": "Token is valid"
}
```

## Testing Features

The API supports comprehensive user management with:

- **Role-based access control** - Users get default "User" role with specific permissions
- **Multi-language support** - English, Spanish, French, German (en, es, fr, de)
- **Multiple user statuses** - active, inactive, pending, suspended
- **JWT token management** - Secure authentication with token refresh capabilities
- **Input validation** - Comprehensive validation with detailed error messages

## User Roles and Permissions

Default user roles in the system:
- **Super Admin** - Full system access
- **Admin** - Administrative privileges
- **Manager** - Management-level access
- **Analyst** - Data analysis capabilities  
- **Developer** - Development resources access
- **Reviewer** - Review and approval capabilities
- **Sales** - Sales-related permissions
- **User** - Basic user permissions (default for new registrations)

## Development Environment

The system comes with pre-seeded data including:
- 15+ test users across different roles
- Comprehensive permissions system
- Role-permission mappings
- Sample data for testing

## Error Handling

Common errors and their responses:

- **422 Unprocessable Entity** - Validation errors
- **401 Unauthorized** - Invalid credentials or missing token
- **404 Not Found** - Endpoint not found
- **500 Internal Server Error** - Server errors

## Security Features

- JWT token-based authentication
- Password confirmation validation
- Email uniqueness validation
- Token expiration and refresh
- Role-based authorization
- CORS support for API access

## Next Steps

1. Review the detailed documentation files
2. Test the examples with your local server
3. Adapt the examples for your specific use case
4. Implement proper error handling in your client application
5. Consider security implications for production deployment

## Need Help?

- Check the detailed documentation in the `docs/` directory
- All examples are tested and working with the current API version
- Examples use `localhost:3000` - adjust the URL for your environment
