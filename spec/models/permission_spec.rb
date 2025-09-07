require 'rails_helper'

RSpec.describe Permission, type: :model do
  describe 'factory' do
    it 'creates a valid permission' do
      permission = build(:permission)
      expect(permission).to be_valid
    end

    it 'creates permissions with different traits' do
      create_users = build(:permission, :create_users)
      read_users = build(:permission, :read_users)
      custom = build(:permission, :custom_permission)

      expect(create_users.name).to eq('Create Users')
      expect(read_users.name).to eq('Read Users')
      expect(create_users.resource).to eq('users')
      expect(read_users.resource).to eq('users')
      expect(custom.is_system).to be false
    end
  end

  describe 'validations' do
    let(:permission) { build(:permission) }

    describe 'name' do
      it 'requires a name' do
        permission.name = nil
        expect(permission).not_to be_valid
        expect(permission.errors[:name]).to include("can't be blank")
      end

      it 'requires a unique name' do
        existing_permission = create(:permission, name: 'Unique Name')
        permission.name = 'Unique Name'
        expect(permission).not_to be_valid
        expect(permission.errors[:name]).to include('has already been taken')
      end
    end

    describe 'resource' do
      it 'requires a resource' do
        permission.resource = nil
        expect(permission).not_to be_valid
        expect(permission.errors[:resource]).to include("can't be blank")
      end
    end

    describe 'action' do
      it 'requires an action' do
        permission.action = nil
        expect(permission).not_to be_valid
        expect(permission.errors[:action]).to include("can't be blank")
      end
    end

    describe 'resource and action uniqueness' do
      it 'requires unique resource and action combination' do
        existing_permission = create(:permission, resource: 'users', action: 'create')
        permission.resource = 'users'
        permission.action = 'create'
        expect(permission).not_to be_valid
        expect(permission.errors[:resource]).to include('has already been taken')
      end

      it 'allows same resource with different action' do
        existing_permission = create(:permission, resource: 'users', action: 'create')
        permission.resource = 'users'
        permission.action = 'read'
        expect(permission).to be_valid
      end

      it 'allows same action with different resource' do
        existing_permission = create(:permission, resource: 'users', action: 'create')
        permission.resource = 'roles'
        permission.action = 'create'
        expect(permission).to be_valid
      end
    end
  end

  describe 'associations' do
    it 'has many roles' do
      permission = create(:permission)
      role1 = create(:role)
      role2 = create(:role)

      permission.roles << role1
      permission.roles << role2

      expect(permission.roles).to include(role1, role2)
      expect(permission.roles.count).to eq(2)
    end
  end

  describe 'scopes' do
    let!(:system_permission1) { create(:permission, is_system: true) }
    let!(:system_permission2) { create(:permission, is_system: true) }
    let!(:custom_permission1) { create(:permission, is_system: false) }
    let!(:custom_permission2) { create(:permission, is_system: false) }

    describe '.system_permissions' do
      it 'returns only system permissions' do
        result = Permission.system_permissions
        expect(result).to include(system_permission1, system_permission2)
        expect(result).not_to include(custom_permission1, custom_permission2)
        expect(result.count).to eq(2)
      end
    end

    describe '.custom_permissions' do
      it 'returns only custom permissions' do
        result = Permission.custom_permissions
        expect(result).to include(custom_permission1, custom_permission2)
        expect(result).not_to include(system_permission1, system_permission2)
        expect(result.count).to eq(2)
      end
    end

    describe '.for_resource' do
      let!(:users_permission) { create(:permission, resource: 'users') }
      let!(:roles_permission) { create(:permission, resource: 'roles') }

      it 'returns permissions for specific resource' do
        result = Permission.for_resource('users')
        expect(result).to include(users_permission)
        expect(result).not_to include(roles_permission)
      end
    end

    describe '.for_action' do
      let!(:create_permission) { create(:permission, action: 'create') }
      let!(:read_permission) { create(:permission, action: 'read') }

      it 'returns permissions for specific action' do
        result = Permission.for_action('create')
        expect(result).to include(create_permission)
        expect(result).not_to include(read_permission)
      end
    end
  end

  describe 'callbacks' do
    describe '#generate_id' do
      it 'generates an ID automatically' do
        permission = create(:permission)
        expect(permission.id).to match(/perm-\d{3}/)
      end

      it 'generates sequential IDs' do
        permission1 = create(:permission)
        permission2 = create(:permission)

        id1_number = permission1.id.match(/perm-(\d{3})/)[1].to_i
        id2_number = permission2.id.match(/perm-(\d{3})/)[1].to_i

        expect(id2_number).to eq(id1_number + 1)
      end

      it 'does not override existing ID' do
        permission = build(:permission)
        permission.id = 'custom-id'
        permission.save!
        expect(permission.id).to eq('custom-id')
      end
    end

    describe '#normalize_resource_and_action' do
      it 'normalizes resource to lowercase and plural' do
        permission = create(:permission, resource: 'USER', action: 'READ')
        expect(permission.resource).to eq('users')
        expect(permission.action).to eq('read')
      end

      it 'handles already plural resources' do
        permission = create(:permission, resource: 'Users', action: 'Create')
        expect(permission.resource).to eq('users')
        expect(permission.action).to eq('create')
      end

      it 'handles mixed case inputs' do
        permission = create(:permission, resource: 'RePort', action: 'MaNaGe')
        expect(permission.resource).to eq('reports')
        expect(permission.action).to eq('manage')
      end
    end
  end

  describe 'class methods' do
    describe '.create_permission' do
      it 'creates a permission with all attributes' do
        permission = Permission.create_permission(
          name: 'Test Permission',
          description: 'Test description',
          resource: 'test_resource',
          action: 'test_action',
          is_system: false
        )

        expect(permission).to be_persisted
        expect(permission.name).to eq('Test Permission')
        expect(permission.description).to eq('Test description')
        expect(permission.resource).to eq('test_resources')
        expect(permission.action).to eq('test_action')
        expect(permission.is_system).to be false
      end

      it 'defaults is_system to true' do
        permission = Permission.create_permission(
          name: 'Test Permission',
          description: 'Test description',
          resource: 'test_resource',
          action: 'test_action'
        )

        expect(permission.is_system).to be true
      end
    end
  end

  describe 'instance methods' do
    let(:system_permission) { create(:permission, is_system: true) }
    let(:custom_permission) { create(:permission, is_system: false) }

    describe '#system_permission?' do
      it 'returns true for system permissions' do
        expect(system_permission.system_permission?).to be true
      end

      it 'returns false for custom permissions' do
        expect(custom_permission.system_permission?).to be false
      end
    end

    describe '#custom_permission?' do
      it 'returns true for custom permissions' do
        expect(custom_permission.custom_permission?).to be true
      end

      it 'returns false for system permissions' do
        expect(system_permission.custom_permission?).to be false
      end
    end

    describe '#full_name' do
      it 'returns resource:action format' do
        permission = create(:permission, resource: 'users', action: 'create')
        expect(permission.full_name).to eq('users:create')
      end
    end

    describe '#to_s' do
      it 'returns the permission name' do
        permission = create(:permission, name: 'Test Permission')
        expect(permission.to_s).to eq('Test Permission')
      end
    end
  end

  describe 'permission traits with roles' do
    it 'creates system permissions with proper attributes' do
      create_users = create(:permission, :create_users)
      expect(create_users.name).to eq('Create Users')
      expect(create_users.resource).to eq('users')
      expect(create_users.action).to eq('create')
      expect(create_users.is_system).to be true
    end

    it 'creates custom permissions' do
      custom = create(:permission, :custom_permission)
      expect(custom.is_system).to be false
      expect(custom.resource).to start_with('custom_resource_')
    end

    it 'allows associating with roles' do
      permission = create(:permission, :create_users)
      role = create(:role)

      role.permissions << permission

      expect(role.permissions).to include(permission)
      expect(permission.roles).to include(role)
    end
  end
end
