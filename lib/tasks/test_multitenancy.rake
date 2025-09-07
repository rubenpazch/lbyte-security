# frozen_string_literal: true

namespace :test do
  desc "Test multitenancy setup"
  task :multitenancy => :environment do
    puts "Testing multitenancy setup..."
    
    begin
      # Test basic gem functionality
      puts "Current schema: #{PgMultitenantSchemas.current_schema}"
      
      # List available schemas
      connection = ActiveRecord::Base.connection
      schemas = connection.execute(
        "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast_temp_1', 'pg_temp_1', 'public') AND schema_name NOT LIKE 'pg_toast%'"
      ).map { |row| row['schema_name'] }
      
      puts "Available tenant schemas: #{schemas.join(', ')}"
      
      # Test schema switching
      if schemas.any?
        test_schema = schemas.first
        puts "Testing schema switch to: #{test_schema}"
        
        PgMultitenantSchemas.with_tenant(test_schema) do
          puts "Successfully switched to schema: #{PgMultitenantSchemas.current_schema}"
        end
        
        puts "Back to original schema: #{PgMultitenantSchemas.current_schema}"
      end
      
      puts "Multitenancy test completed successfully!"
      
    rescue => e
      puts "Error during multitenancy test: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
end
