# Token Verification System

## Overview
This system provides comprehensive JWT token verification, information retrieval, and refresh capabilities for the LByte Security authentication system.

## Endpoints

### `GET /token/verify`
**Purpose**: Verify if a JWT token is valid and return comprehensive user information.

**Headers**: 
```
Authorization: Bearer <JWT_TOKEN>
```

**Success Response (200)**:
```json
{
  "valid": true,
  "user": {
    "id": 26,
    "email": "admin@lbytesecurity.com",
    "username": "admin",
    "first_name": "System",
    "last_name": "Admin",
    "roles": ["User", "Super Admin"],
    "permissions": ["Read Users", "Update Users", "Manage Users", ...],
    "is_admin": true,
    "is_active": true,
    "email_verified": true
  },
  "message": "Token is valid"
}
```

**Error Response (401)**:
```json
{
  "valid": false,
  "error": "Invalid or expired token",
  "message": "The provided JWT token is either invalid, expired, or malformed"
}
```

### `GET /token/info`
**Purpose**: Get token metadata without full authentication (useful for debugging).

**Headers**: 
```
Authorization: Bearer <JWT_TOKEN>
```

**Success Response (200)**:
```json
{
  "token_info": {
    "user_id": "26",
    "issued_at": "2025-08-16T20:08:08.000-05:00",
    "expires_at": "2025-08-17T20:08:08.000-05:00",
    "jti": "1dfed52b-d255-45f1-8ddf-2336e66b4062",
    "is_expired": false
  },
  "message": "Token information retrieved"
}
```

**Error Response (400)**:
```json
{
  "error": "No token provided",
  "message": "Authorization header with Bearer token is required"
}
```

### `POST /token/refresh`
**Purpose**: Refresh a token by issuing a new one (requires valid existing token).

**Headers**: 
```
Authorization: Bearer <JWT_TOKEN>
```

**Success Response (200)**:
```json
{
  "message": "Token refreshed successfully",
  "user": {
    "id": 26,
    "email": "admin@lbytesecurity.com",
    "roles": ["User", "Super Admin"]
  }
}
```

**Error Response (401)**:
```json
{
  "error": "Cannot refresh token",
  "message": "Current token is invalid or expired"
}
```

## Usage Examples

### 1. Complete Authentication Flow
```bash
# Login
curl -i -X POST http://localhost:3000/users/sign_in \
  -H "Content-Type: application/json" \
  -d '{"user": {"email": "admin@lbytesecurity.com", "password": "AdminPass123!"}}'

# Extract token from Authorization header in response
TOKEN="eyJhbGciOiJIUzI1NiJ9..."

# Verify token
curl -X GET http://localhost:3000/token/verify \
  -H "Authorization: Bearer $TOKEN"

# Get token info
curl -X GET http://localhost:3000/token/info \
  -H "Authorization: Bearer $TOKEN"

# Refresh token
curl -X POST http://localhost:3000/token/refresh \
  -H "Authorization: Bearer $TOKEN"

# Logout
curl -X DELETE http://localhost:3000/users/sign_out \
  -H "Authorization: Bearer $TOKEN"
```

### 2. Frontend Integration Example (JavaScript)
```javascript
// Check if stored token is still valid
async function verifyToken(token) {
  try {
    const response = await fetch('/token/verify', {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });
    
    if (response.ok) {
      const data = await response.json();
      return data.valid ? data.user : null;
    }
    return null;
  } catch (error) {
    console.error('Token verification failed:', error);
    return null;
  }
}

// Get token expiration info
async function getTokenInfo(token) {
  const response = await fetch('/token/info', {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  
  return response.json();
}

// Refresh token before expiration
async function refreshToken(token) {
  const response = await fetch('/token/refresh', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  
  if (response.ok) {
    // New token will be in response headers
    const newToken = response.headers.get('Authorization')?.replace('Bearer ', '');
    return newToken;
  }
  
  return null;
}
```

## Test Coverage

### Unit Tests (`spec/controllers/token_controller_spec.rb`)
- ✅ Token verification with valid tokens
- ✅ Token verification without tokens  
- ✅ Token verification with invalid tokens
- ✅ Token info retrieval
- ✅ Token refresh functionality
- ✅ Error handling for all scenarios

### Integration Tests (`spec/requests/token_verification_spec.rb`)
- ✅ Complete authentication flow (login → verify → info → refresh → logout)
- ✅ Invalid token handling
- ✅ Missing token handling  
- ✅ Expired token detection
- ✅ Expired token rejection

**Total Test Coverage**: 13 examples, 0 failures

## Security Features

1. **JWT Signature Verification**: All tokens are cryptographically verified
2. **Expiration Checking**: Tokens are validated for expiration
3. **User Status Validation**: Inactive users are rejected even with valid tokens
4. **Comprehensive Error Handling**: Detailed error messages for debugging
5. **Token Blacklisting**: Integration with JWT denylist system

## Error Handling

The system handles various error scenarios:
- Invalid token format
- Expired tokens  
- Missing tokens
- Inactive users
- Malformed authorization headers
- Network errors

All errors return appropriate HTTP status codes and descriptive messages.
