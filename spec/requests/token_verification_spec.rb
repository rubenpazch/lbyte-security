require 'rails_helper'

RSpec.describe "Token Verification API", type: :request do
  let(:user) { create(:user, :super_admin) }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }

  describe 'Token Verification Flow' do
    it 'can login, verify token, get info, and refresh token' do
      # Step 1: Login to get JWT token
      post '/users/sign_in', params: {
        user: {
          email: user.email,
          password: 'password123'
        }
      }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      token = response.headers['Authorization'].gsub('Bearer ', '')
      expect(token).to be_present

      auth_headers = headers.merge('Authorization' => "Bearer #{token}")

      # Step 2: Verify the token
      get '/token/verify', headers: auth_headers

      expect(response).to have_http_status(:ok)
      verify_response = JSON.parse(response.body)
      expect(verify_response['valid']).to be true
      expect(verify_response['user']['email']).to eq(user.email)
      expect(verify_response['user']['roles']).to include('Super Admin')

      # Step 3: Get token info
      get '/token/info', headers: auth_headers

      expect(response).to have_http_status(:ok)
      info_response = JSON.parse(response.body)
      expect(info_response['token_info']['user_id']).to eq(user.id.to_s)
      expect(info_response['token_info']['is_expired']).to be false

      # Step 4: Refresh the token
      post '/token/refresh', headers: auth_headers

      expect(response).to have_http_status(:ok)
      refresh_response = JSON.parse(response.body)
      expect(refresh_response['message']).to eq('Token refreshed successfully')
      expect(refresh_response['user']['email']).to eq(user.email)

      # Step 5: Logout
      delete '/users/sign_out', headers: auth_headers

      expect(response).to have_http_status(:no_content)
    end

    it 'handles invalid token properly' do
      # Try to verify an invalid token
      get '/token/verify', headers: headers.merge('Authorization' => 'Bearer invalid_token')
      expect(response).to have_http_status(:unauthorized)

      # Try to get info with invalid token
      get '/token/info', headers: headers.merge('Authorization' => 'Bearer invalid_token')
      expect(response).to have_http_status(:bad_request)

      error_response = JSON.parse(response.body)
      expect(error_response['error']).to eq('Invalid token format')
    end

    it 'handles missing token properly' do
      # Try to verify without token
      get '/token/verify', headers: headers
      expect(response).to have_http_status(:unauthorized)

      # Try to get info without token
      get '/token/info', headers: headers
      expect(response).to have_http_status(:bad_request)

      error_response = JSON.parse(response.body)
      expect(error_response['error']).to eq('No token provided')
    end
  end

  describe 'Token Expiration' do
    let(:expired_payload) do
      {
        sub: user.id,
        scp: 'user',
        aud: nil,
        iat: 2.days.ago.to_i,
        exp: 1.day.ago.to_i,  # Expired yesterday
        jti: SecureRandom.uuid
      }
    end

    let(:expired_token) do
      secret = ENV["JWT_SECRET_KEY"] || "d7bc50f70bee26c86a9b9a6addebd02215c4f21438b7ffd3a49638102867be75d8f3e4ddf0dc05958aff54a6a1313c2130c80f299fe319de7dd19d58ac05bfda"
      JWT.encode(expired_payload, secret, 'HS256')
    end

    it 'detects expired tokens in token info endpoint' do
      get '/token/info', headers: headers.merge('Authorization' => "Bearer #{expired_token}")

      expect(response).to have_http_status(:ok)
      info_response = JSON.parse(response.body)
      expect(info_response['token_info']['is_expired']).to be true
      expect(info_response['message']).to eq('Token is expired')
    end

    it 'rejects expired tokens in verify endpoint' do
      get '/token/verify', headers: headers.merge('Authorization' => "Bearer #{expired_token}")

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
