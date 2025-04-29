# filepath: /home/rubenpaz/lbyte/lbyte-security/lib/custom_failure.rb
class CustomFailure < Devise::FailureApp
    def respond
      if request.format.json?
        json_error_response
      else
        super
      end
    end

    private

    def json_error_response
      self.status = :unauthorized
      self.content_type = "application/json"
      self.response_body = { error: i18n_message }.to_json
    end
end
