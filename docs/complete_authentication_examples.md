# Complete API Authentication Examples

This document provides comprehensive curl examples for the complete authentication workflow in the LByte Security API.

## Authentication Workflow

1. **Register** a new user account
2. **Sign in** to get a JWT token
3. **Use the token** for authenticated requests
4. **Verify token** validity
5. **Refresh token** when needed
6. **Sign out** (optional)

## 1. User Registration

### Basic Registration
```bash
curl -i -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "demo@example.com",
      "password": "password123",
      "password_confirmation": "password123",
      "username": "demouser",
      "first_name": "Demo",
      "last_name": "User"
    }
  }'
```

## 2. User Sign In

After registration, sign in to get a JWT token:

```bash
curl -i -X POST http://localhost:3000/users/sign_in \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "demo@example.com",
      "password": "password123"
    }
  }'
```

**Expected Response Headers:**
```
HTTP/1.1 200 OK
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNjMzMTIzNDU2LCJleHAiOjE2MzMxMjcwNTYsImp0aSI6IjEyMzQ1Njc4OTAifQ.example_jwt_token
```

**Response Body:**
```json
{
  "status": {
    "code": 200,
    "message": "Logged in successfully."
  },
  "data": {
    "user": {
      "id": 1,
      "email": "demo@example.com",
      "username": "demouser",
      "first_name": "Demo",
      "last_name": "User",
      "roles": ["User"]
    }
  }
}
```

## 3. Using JWT Token for Authenticated Requests

Extract the JWT token from the `Authorization` header and use it for subsequent requests:

```bash
# Set the token as a variable (replace with actual token)
TOKEN="eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNjMzMTIzNDU2LCJleHAiOjE2MzMxMjcwNTYsImp0aSI6IjEyMzQ1Njc4OTAifQ.example_jwt_token"

# Make authenticated requests
curl -i -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  http://localhost:3000/protected_endpoint
```

## 4. Token Verification

Verify if your token is still valid:

```bash
curl -i -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  http://localhost:3000/token/verify
```

**Success Response:**
```json
{
  "status": "valid",
  "message": "Token is valid",
  "expires_at": "2025-08-17T02:30:00Z"
}
```

## 5. Token Information

Get detailed information about your token:

```bash
curl -i -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  http://localhost:3000/token/info
```

**Response:**
```json
{
  "status": "active",
  "user_id": 1,
  "email": "demo@example.com",
  "roles": ["User"],
  "issued_at": "2025-08-17T01:30:00Z",
  "expires_at": "2025-08-17T02:30:00Z"
}
```

## 6. Token Refresh

Refresh your token to extend its validity:

```bash
curl -i -X POST http://localhost:3000/token/refresh \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

## 7. User Sign Out

Sign out and invalidate the token:

```bash
curl -i -X DELETE http://localhost:3000/users/sign_out \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

## Complete Example Script

Here's a complete bash script that demonstrates the entire workflow:

```bash
#!/bin/bash

API_BASE="http://localhost:3000"

echo "=== Step 1: Register a new user ==="
curl -i -X POST "$API_BASE/users" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "script_demo@example.com",
      "password": "password123",
      "password_confirmation": "password123",
      "username": "scriptdemo",
      "first_name": "Script",
      "last_name": "Demo"
    }
  }'

echo -e "\n\n=== Step 2: Sign in to get token ==="
RESPONSE=$(curl -s -i -X POST "$API_BASE/users/sign_in" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "script_demo@example.com",
      "password": "password123"
    }
  }')

# Extract the token from the Authorization header
TOKEN=$(echo "$RESPONSE" | grep -i "authorization:" | cut -d' ' -f2- | tr -d '\r\n')

echo "Token: $TOKEN"

echo -e "\n\n=== Step 3: Verify token ==="
curl -i -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$API_BASE/token/verify"

echo -e "\n\n=== Step 4: Get token info ==="
curl -i -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$API_BASE/token/info"

echo -e "\n\n=== Step 5: Refresh token ==="
curl -i -X POST "$API_BASE/token/refresh" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"

echo -e "\n\n=== Step 6: Sign out ==="
curl -i -X DELETE "$API_BASE/users/sign_out" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"

echo -e "\n\nWorkflow completed!"
```

## Error Handling

### Common Authentication Errors

#### Invalid Credentials
```bash
curl -i -X POST http://localhost:3000/users/sign_in \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "demo@example.com",
      "password": "wrongpassword"
    }
  }'
```

**Response:**
```json
{
  "status": {
    "message": "Invalid Email or password."
  }
}
```

#### Expired/Invalid Token
```bash
curl -i -H "Authorization: Bearer invalid_token" \
  -H "Content-Type: application/json" \
  http://localhost:3000/token/verify
```

**Response:**
```json
{
  "status": "invalid",
  "message": "Invalid or expired token"
}
```

#### Missing Authorization Header
```bash
curl -i -H "Content-Type: application/json" \
  http://localhost:3000/token/verify
```

**Response:**
```json
{
  "status": "unauthorized",
  "message": "Authorization header missing"
}
```

## Testing with Different User Roles

The system supports different user roles that may have different permissions:

### Create Admin User (if you have super admin privileges)
```bash
curl -i -X POST http://localhost:3000/users \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "admin@example.com",
      "password": "adminpassword123",
      "password_confirmation": "adminpassword123",
      "username": "adminuser",
      "first_name": "Admin",
      "last_name": "User"
    }
  }'
```

Then assign admin role through your application interface or Rails console.

## Production Considerations

1. **HTTPS**: Always use HTTPS in production
2. **Token Storage**: Store tokens securely (not in localStorage for sensitive apps)
3. **Token Expiry**: Implement automatic token refresh
4. **Error Handling**: Handle all error scenarios gracefully
5. **Rate Limiting**: Be aware of API rate limits
6. **CORS**: Configure CORS properly for browser-based applications

## Security Best Practices

1. **Strong Passwords**: Enforce strong password requirements
2. **Token Rotation**: Refresh tokens regularly
3. **Secure Headers**: Always include proper security headers
4. **Input Validation**: Validate all input data
5. **Audit Logging**: Log authentication events for security monitoring
