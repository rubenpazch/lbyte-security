# API Documentation - User Registration Endpoints

This document provides comprehensive curl request examples for user registration endpoints in the LByte Security API.

## User Registration

### Endpoint
```
POST /users
```

### Headers
```
Content-Type: application/json
```

### Required Parameters
- `email`: User's email address (must be unique)
- `password`: User's password (minimum 6 characters)
- `password_confirmation`: Password confirmation (must match password)

### Optional Parameters (with defaults)
- `username`: Unique username for the user (can be blank)
- `status`: User status (`active` [default], `inactive`, `pending`, `suspended`)
- `language`: User's preferred language (`en` [default], `es`, `fr`, `de`)
- `first_name`: User's first name
- `last_name`: User's last name

## Examples

### 1. Minimal Registration (Required Fields Only)

```bash
curl -i -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "minimal@example.com",
      "password": "password123",
      "password_confirmation": "password123"
    }
  }'
```

*Note: This will create a user with default values: `status: "active"`, `language: "en"`, and `username: null`*

### 2. Basic Registration (Recommended Fields)

```bash
curl -i -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "john.doe@example.com",
      "password": "securepassword123",
      "password_confirmation": "securepassword123",
      "username": "johndoe",
      "status": "active",
      "language": "en"
    }
  }'
```

### 3. Complete Registration (All Fields)

```bash
curl -i -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "jane.smith@example.com",
      "password": "mypassword456",
      "password_confirmation": "mypassword456",
      "username": "janesmith",
      "status": "active",
      "language": "en",
      "first_name": "Jane",
      "last_name": "Smith"
    }
  }'
```

### 4. Registration with Different Languages

```bash
# Spanish user
curl -i -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "carlos.lopez@example.com",
      "password": "mipassword789",
      "password_confirmation": "mipassword789",
      "username": "carloslopez",
      "status": "active",
      "language": "es",
      "first_name": "Carlos",
      "last_name": "López"
    }
  }'

# French user
curl -i -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "marie.dubois@example.com",
      "password": "motdepasse321",
      "password_confirmation": "motdepasse321",
      "username": "mariedubois",
      "status": "active",
      "language": "fr",
      "first_name": "Marie",
      "last_name": "Dubois"
    }
  }'
```

### 5. Registration with Different Status Types

```bash
# Pending user
curl -i -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "pending.user@example.com",
      "password": "password123",
      "password_confirmation": "password123",
      "username": "pendinguser",
      "status": "pending",
      "language": "en"
    }
  }'

# Inactive user
curl -i -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "inactive.user@example.com",
      "password": "password123",
      "password_confirmation": "password123",
      "username": "inactiveuser",
      "status": "inactive",
      "language": "en"
    }
  }'
```

### 6. Testing for Compact JSON Format

```bash
curl -i -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"compact@example.com","password":"password123","password_confirmation":"password123","username":"compactuser","status":"active","language":"en"}}'
```

## Response Examples

### Successful Registration (201 Created)

```json
{
  "status": {
    "code": 200,
    "message": "Signed up successfully."
  },
  "data": {
    "id": 42,
    "email": "john.doe@example.com",
    "username": "johndoe",
    "status": "active",
    "language": "en",
    "first_name": "John",
    "last_name": "Doe",
    "roles": ["User"],
    "created_at": "2025-08-17T01:35:16.899Z",
    "updated_at": "2025-08-17T01:35:16.899Z"
  }
}
```

### Validation Errors (422 Unprocessable Entity)

```json
{
  "status": {
    "message": "User couldn't be created successfully. Email has already been taken and Username has already been taken"
  },
  "errors": [
    "Email has already been taken",
    "Username has already been taken"
  ]
}
```

## Common Error Scenarios

### 1. Duplicate Email

```bash
curl -i -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "existing@example.com",
      "password": "password123",
      "password_confirmation": "password123",
      "username": "newusername",
      "status": "active",
      "language": "en"
    }
  }'
```

**Response:**
```json
{
  "status": {
    "message": "User couldn't be created successfully. Email has already been taken"
  },
  "errors": ["Email has already been taken"]
}
```

### 2. Password Mismatch

```bash
curl -i -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "test@example.com",
      "password": "password123",
      "password_confirmation": "different_password",
      "username": "testuser",
      "status": "active",
      "language": "en"
    }
  }'
```

**Response:**
```json
{
  "status": {
    "message": "User couldn't be created successfully. Password confirmation doesn't match Password"
  },
  "errors": ["Password confirmation doesn't match Password"]
}
```

### 3. Missing Required Fields

```bash
curl -i -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "incomplete@example.com",
      "password": "password123"
    }
  }'
```

**Response:**
```json
{
  "status": {
    "code": 200,
    "message": "Signed up successfully."
  },
  "data": {
    "id": 43,
    "email": "incomplete@example.com",
    "username": null,
    "status": "active",
    "language": "en",
    "first_name": null,
    "last_name": null,
    "roles": ["User"],
    "created_at": "2025-08-17T01:36:14.929Z",
    "updated_at": "2025-08-17T01:36:14.929Z"
  }
}
```

*Note: This succeeds because `password_confirmation` defaults to matching `password` when omitted, and `status`/`language` have default values.*

### 4. Invalid Status Value

```bash
curl -i -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "invalid@example.com",
      "password": "password123",
      "password_confirmation": "password123",
      "status": "invalid_status"
    }
  }'
```

**Response:**
```json
{
  "status": {
    "message": "User couldn't be created successfully. Status is not included in the list"
  },
  "errors": ["Status is not included in the list"]
}
```

## Additional Registration Routes

The following Devise routes are also available:

- `GET /users/sign_up` - Get registration form (HTML format, API may not use)
- `GET /users/edit` - Get edit profile form (requires authentication)
- `PUT /users` - Update user profile (requires authentication)  
- `DELETE /users` - Delete user account (requires authentication)

## Authentication After Registration

After successful registration, users need to sign in to get a JWT token:

```bash
curl -i -X POST http://localhost:3000/users/sign_in \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "john.doe@example.com",
      "password": "securepassword123"
    }
  }'
```

The sign-in response will include a JWT token in the `Authorization` header that can be used for authenticated requests.

## Testing Tips

1. Always use unique email addresses and usernames when testing
2. Use `-i` flag with curl to see response headers and status codes
3. Validate your JSON payload before sending (malformed JSON will result in parsing errors)
4. Check the response status code: 200 for success, 422 for validation errors
5. The created user will automatically get the "User" role assigned by default

## Server Requirements

- Rails server must be running on the specified host and port
- Database must be properly migrated and seeded
- CORS must be configured if calling from a browser application
