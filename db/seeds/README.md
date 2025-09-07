# Seeds Documentation

This directory contains environment-specific seed files for the lbyte-security application.

## Structure

```
db/seeds/
├── development.rb  # Sample users and development data
├── production.rb   # Essential production data only
├── test.rb        # Test environment data (usually empty)
└── README.md      # This file
```

## Usage

### Development Environment
```bash
bundle exec rails db:seed
```
Creates sample users for testing the authentication system.

### Production Environment
```bash
RAILS_ENV=production bundle exec rails db:seed
```
Only creates essential system data. No sample users for security.

### Test Environment
```bash
RAILS_ENV=test bundle exec rails db:seed
```
Minimal seeding. Tests should create their own data using factories.

## Development Users

The development seeds create the following users:

| Email | Password | Purpose |
|-------|----------|---------|
| admin@example.com | password123 | Admin user |
| user@example.com | password123 | Regular user |
| test@example.com | password123 | Testing user |
| demo@example.com | password123 | Demo purposes |
| alice@example.com | securepass456 | Different password |
| bob@example.com | strongpass789 | Different password |
| developer@lbyte.com | devpass2024 | Developer account |
| security@lbyte.com | securepass2024 | Security testing |

## API Testing

You can test authentication with any of these users:

```bash
# Sign in
curl -X POST http://localhost:3000/users/sign_in \
  -H "Content-Type: application/json" \
  -d '{"user": {"email": "admin@example.com", "password": "password123"}}'

# Sign out (replace YOUR_JWT_TOKEN with the actual token)
curl -X DELETE http://localhost:3000/users/sign_out \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Security Notes

- Development seeds clear all existing users first
- Production seeds should never create default users with known passwords
- Test seeds should be minimal as tests create their own data
- Always use environment variables for production passwords
