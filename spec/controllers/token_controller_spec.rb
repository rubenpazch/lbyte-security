require 'rails_helper'

RSpec.describe TokenController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user, :admin) }

  # Helper method to create a valid JWT token for testing
  def jwt_token_for(user)
    payload = {
      sub: user.id,
      scp: 'user',
      aud: nil,
      iat: Time.current.to_i,
      exp: 1.day.from_now.to_i,
      jti: SecureRandom.uuid
    }
    secret = ENV["JWT_SECRET_KEY"] || "d7bc50f70bee26c86a9b9a6addebd02215c4f21438b7ffd3a49638102867be75d8f3e4ddf0dc05958aff54a6a1313c2130c80f299fe319de7dd19d58ac05bfda"
    JWT.encode(payload, secret, 'HS256')
  end

  describe 'GET #verify' do
    context 'with valid token' do
      before do
        token = jwt_token_for(user)
        request.headers['Authorization'] = "Bearer #{token}"
        sign_in user
      end

      it 'returns token validation success' do
        get :verify, format: :json
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['valid']).to be true
        expect(json['user']['email']).to eq(user.email)
        expect(json['user']).to have_key('roles')
        expect(json['user']).to have_key('permissions')
        expect(json['message']).to eq('Token is valid')
      end
    end

    context 'without token' do
      it 'returns unauthorized' do
        get :verify
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid token' do
      before do
        request.headers['Authorization'] = 'Bearer invalid_token'
      end

      it 'returns token validation failure' do
        get :verify
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #info' do
    context 'with valid token' do
      let(:jwt_token) { jwt_token_for(user) }

      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'returns token information' do
        get :info
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['token_info']).to have_key('user_id')
        expect(json['token_info']).to have_key('issued_at')
        expect(json['token_info']).to have_key('expires_at')
        expect(json['token_info']).to have_key('is_expired')
        expect(json['token_info']['is_expired']).to be false
      end
    end

    context 'without token' do
      it 'returns bad request' do
        get :info
        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('No token provided')
      end
    end

    context 'with malformed token' do
      before do
        request.headers['Authorization'] = 'Bearer malformed_token'
      end

      it 'returns bad request with decode error' do
        get :info
        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('Invalid token format')
      end
    end
  end

  describe 'POST #refresh' do
    context 'with valid token' do
      before do
        token = jwt_token_for(user)
        request.headers['Authorization'] = "Bearer #{token}"
        sign_in user
      end

      it 'refreshes the token successfully' do
        post :refresh
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['message']).to eq('Token refreshed successfully')
        expect(json['user']['email']).to eq(user.email)
      end
    end

    context 'without valid token' do
      it 'returns unauthorized' do
        post :refresh
        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('Cannot refresh token')
      end
    end
  end
end
