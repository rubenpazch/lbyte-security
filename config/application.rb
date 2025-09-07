require_relative "boot"

# Load only the necessary Rails components for an API-only app
require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_cable/engine"        # Add back ActionCable for RSpec compatibility
# require "action_mailbox/engine"   # Remove Action Mailbox
# require "action_text/engine"      # Remove Action Text
# require "active_storage/engine"   # Remove Active Storage if not needed
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module LbyteSecurity
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    config.eager_load_paths << Rails.root.join("lib")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # Load custom middleware (temporarily disabled)
    # config.autoload_paths << Rails.root.join("app", "middleware")

    # Add tenant middleware for automatic tenant resolution (temporarily disabled for testing)
    # config.middleware.use "TenantMiddleware"

    # Additional API-only optimizations can be added here
  end
end
