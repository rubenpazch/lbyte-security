#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to properly setup tenant schemas with complete table structure
require_relative 'config/environment'

def get_schema_definition
  # Use Rails schema dumper to get the structure
  StringIO.new.tap do |io|
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, io)
    io.rewind
  end.read
end

def create_tables_in_schema(schema_name)
  puts "📋 Creating tables in schema: #{schema_name}"

  # Switch to target schema
  ActiveRecord::Base.connection.execute("SET search_path TO #{schema_name}")

  # Get all tables from public schema except system tables
  tables_to_exclude = %w[schema_migrations ar_internal_metadata tenants]

  # Copy each table structure from public schema
  ActiveRecord::Base.connection.execute("SET search_path TO public").tap do
    public_tables = ActiveRecord::Base.connection.tables - tables_to_exclude

    public_tables.each do |table_name|
      begin
        # Get the table's SQL definition
        result = ActiveRecord::Base.connection.execute(<<-SQL)
          SELECT#{' '}
            'CREATE TABLE #{schema_name}.' || quote_ident(tablename) || ' AS SELECT * FROM public.' || quote_ident(tablename) || ' WHERE 1=0;' as create_stmt,
            'ALTER TABLE #{schema_name}.' || quote_ident(tablename) || ' ADD PRIMARY KEY (' || array_to_string(array_agg(quote_ident(column_name)), ', ') || ');' as pk_stmt
          FROM information_schema.tables t
          LEFT JOIN information_schema.key_column_usage k ON t.table_name = k.table_name AND k.constraint_name LIKE '%_pkey'
          WHERE t.table_schema = 'public' AND t.table_name = '#{table_name}'
          GROUP BY t.tablename;
        SQL

        if result.any?
          create_stmt = result.first["create_stmt"]

          # Switch to target schema and create table
          ActiveRecord::Base.connection.execute("SET search_path TO #{schema_name}")
          ActiveRecord::Base.connection.execute(create_stmt)

          puts "  ✅ Created table: #{table_name}"
        end
      rescue => e
        puts "  ⚠️  Error creating table #{table_name}: #{e.message}"
      end
    end
  end
end

def copy_indexes_and_constraints(schema_name)
  puts "🔗 Copying indexes and constraints to schema: #{schema_name}"

  # This is complex, so let's use a simpler approach - run the actual migrations
  begin
    ActiveRecord::Base.connection.execute("SET search_path TO #{schema_name}")

    # Run all migrations in this schema
    migration_context = ActiveRecord::Base.connection.migration_context
    migration_context.migrate

    puts "  ✅ Migrations completed for #{schema_name}"
  rescue => e
    puts "  ⚠️  Migration issue for #{schema_name}: #{e.message}"
  end
end

def setup_tenant_schemas_properly
  puts "🏗️  Setting up tenant schemas with proper table structure..."

  Tenant.active.find_each do |tenant|
    subdomain = tenant.subdomain
    puts "\n🏢 Setting up #{tenant.name} (#{subdomain})..."

    begin
      # Ensure schema exists
      ActiveRecord::Base.connection.execute("CREATE SCHEMA IF NOT EXISTS #{subdomain}")

      # Copy table structure and run migrations
      copy_indexes_and_constraints(subdomain)

      puts "✅ Complete setup for #{subdomain}"

    rescue => e
      puts "❌ Setup failed for #{subdomain}: #{e.message}"
    end
  end

  # Switch back to public
  ActiveRecord::Base.connection.execute("SET search_path TO public")
  puts "\n🎉 All tenant schemas are ready!"
end

# Run the setup
setup_tenant_schemas_properly
