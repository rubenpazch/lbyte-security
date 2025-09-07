require 'rails_helper'

RSpec.describe Role, type: :model do
  describe 'factory' do
    it 'creates a valid role' do
      role = build(:role)
      expect(role).to be_valid
    end

    it 'creates roles with different traits' do
      super_admin = build(:role, :super_admin_role)
      admin = build(:role, :admin_role)
      user_role = build(:role, :user_role)

      expect(super_admin.name).to eq('Super Admin')
      expect(admin.name).to eq('Admin')
      expect(user_role.name).to eq('User')
    end
  end

  describe 'validations' do
    let(:role) { build(:role) }

    it 'requires a name' do
      role.name = nil
      expect(role).not_to be_valid
      expect(role.errors[:name]).to include("can't be blank")
    end

    it 'requires a unique name' do
      create(:role, name: 'Test Role')
      duplicate_role = build(:role, name: 'Test Role')

      expect(duplicate_role).not_to be_valid
      expect(duplicate_role.errors[:name]).to include("has already been taken")
    end

    it 'requires a level' do
      role.level = nil
      expect(role).not_to be_valid
      expect(role.errors[:level]).to include("can't be blank")
    end

    it 'requires a unique level' do
      create(:role, level: 100)
      duplicate_role = build(:role, level: 100)

      expect(duplicate_role).not_to be_valid
      expect(duplicate_role.errors[:level]).to include("has already been taken")
    end

    it 'requires a valid color format' do
      role.color = 'invalid-color'
      expect(role).not_to be_valid
      expect(role.errors[:color]).to include('is invalid')

      role.color = '#123456'
      expect(role).to be_valid

      role.color = '#ABCDEF'
      expect(role).to be_valid
    end

    it 'requires an icon' do
      role.icon = nil
      expect(role).not_to be_valid
      expect(role.errors[:icon]).to include("can't be blank")
    end
  end

  describe 'associations' do
    let(:role) { create(:role) }
    let(:user) { create(:user) }
    let(:permission) { create(:permission) }

    it 'has many users' do
      expect(role.users).to be_empty
      role.users << user
      expect(role.users).to include(user)
    end

    it 'has many permissions' do
      expect(role.permissions).to be_empty
      role.permissions << permission
      expect(role.permissions).to include(permission)
    end
  end

  describe 'scopes' do
    let!(:system_role) { create(:role, is_system: true) }
    let!(:custom_role) { create(:role, is_system: false) }
    let!(:active_role) { create(:role, is_active: true) }
    let!(:inactive_role) { create(:role, is_active: false) }

    describe '.system_roles' do
      it 'returns only system roles' do
        expect(Role.system_roles).to include(system_role)
        expect(Role.system_roles).not_to include(custom_role)
      end
    end

    describe '.custom_roles' do
      it 'returns only custom roles' do
        expect(Role.custom_roles).to include(custom_role)
        expect(Role.custom_roles).not_to include(system_role)
      end
    end

    describe '.active' do
      it 'returns only active roles' do
        expect(Role.active).to include(active_role)
        expect(Role.active).not_to include(inactive_role)
      end
    end

    describe '.by_level' do
      it 'orders roles by level' do
        role_level_1 = create(:role, level: 1)
        role_level_5 = create(:role, level: 5)
        role_level_3 = create(:role, level: 3)

        ordered_roles = Role.by_level
        expect(ordered_roles.first).to eq(role_level_1)
        expect(ordered_roles.last.level).to be > ordered_roles.first.level
      end
    end
  end

  describe 'callbacks' do
    describe '#generate_id' do
      it 'generates an ID automatically' do
        role = create(:role)
        expect(role.id).to match(/role-\d{3}/)
      end

      it 'generates sequential IDs' do
        first_role = create(:role)
        second_role = create(:role)

        first_number = first_role.id.match(/role-(\d+)/)[1].to_i
        second_number = second_role.id.match(/role-(\d+)/)[1].to_i

        expect(second_number).to be > first_number
      end

      it 'does not override existing ID' do
        role = build(:role)
        role.id = 'custom-id'
        role.save

        expect(role.id).to eq('custom-id')
      end
    end

    describe '#update_user_count' do
      let(:role) { create(:role) }
      let(:user1) { create(:user) }
      let(:user2) { create(:user) }

      it 'updates user count when users are added' do
        expect(role.user_count).to eq(0)

        role.users << user1
        role.save
        role.reload

        expect(role.user_count).to eq(1)

        role.users << user2
        role.save
        role.reload

        expect(role.user_count).to eq(2)
      end
    end
  end

  describe 'instance methods' do
    let(:role) { create(:role) }

    describe '#system_role?' do
      it 'returns true for system roles' do
        role.update(is_system: true)
        expect(role.system_role?).to be true
      end

      it 'returns false for custom roles' do
        role.update(is_system: false)
        expect(role.system_role?).to be false
      end
    end

    describe '#custom_role?' do
      it 'returns true for custom roles' do
        role.update(is_system: false)
        expect(role.custom_role?).to be true
      end

      it 'returns false for system roles' do
        role.update(is_system: true)
        expect(role.custom_role?).to be false
      end
    end

    describe '#has_permission?' do
      let(:permission) { create(:permission, name: 'Test Permission') }

      before do
        role.permissions << permission
      end

      it 'returns true when role has the permission by object' do
        expect(role.has_permission?(permission)).to be true
      end

      it 'returns true when role has the permission by ID' do
        expect(role.has_permission?(permission.id)).to be true
      end

      it 'returns true when role has the permission by name' do
        expect(role.has_permission?('Test Permission')).to be true
      end

      it 'returns false when role does not have the permission' do
        other_permission = create(:permission, name: 'Other Permission')
        expect(role.has_permission?(other_permission)).to be false
        expect(role.has_permission?('Non-existent Permission')).to be false
      end
    end

    describe '#add_permission' do
      let(:permission) { create(:permission, name: 'New Permission') }

      it 'adds permission by object' do
        expect { role.add_permission(permission) }.to change { role.permissions.count }.by(1)
        expect(role.has_permission?(permission)).to be true
      end

      it 'adds permission by ID' do
        expect { role.add_permission(permission.id) }.to change { role.permissions.count }.by(1)
        expect(role.has_permission?(permission)).to be true
      end

      it 'adds permission by name' do
        new_permission = create(:permission, name: 'New Permission')
        expect { role.add_permission('New Permission') }.to change { role.permissions.count }.by(1)
        expect(role.has_permission?('New Permission')).to be true
      end

      it 'does not add duplicate permissions' do
        role.add_permission(permission)
        expect { role.add_permission(permission) }.not_to change { role.permissions.count }
      end

      it 'updates permission_ids array' do
        role.add_permission(permission)
        expect(role.permission_ids).to include(permission.id)
      end
    end

    describe '#remove_permission' do
      let(:permission) { create(:permission, name: 'Remove Me') }

      before do
        role.permissions << permission
        role.save
      end

      it 'removes permission by object' do
        expect { role.remove_permission(permission) }.to change { role.permissions.count }.by(-1)
        expect(role.has_permission?(permission)).to be false
      end

      it 'removes permission by ID' do
        expect { role.remove_permission(permission.id) }.to change { role.permissions.count }.by(-1)
        expect(role.has_permission?(permission)).to be false
      end

      it 'removes permission by name' do
        expect { role.remove_permission('Remove Me') }.to change { role.permissions.count }.by(-1)
        expect(role.has_permission?(permission)).to be false
      end

      it 'updates permission_ids array' do
        role.remove_permission(permission)
        expect(role.permission_ids).not_to include(permission.id)
      end
    end

    describe '#permission_names' do
      let(:permission1) { create(:permission, name: 'Permission One') }
      let(:permission2) { create(:permission, name: 'Permission Two') }

      it 'returns an array of permission names' do
        role.permissions << [ permission1, permission2 ]
        names = role.permission_names

        expect(names).to include('Permission One')
        expect(names).to include('Permission Two')
        expect(names.length).to eq(2)
      end
    end

    describe '#permission_list' do
      let(:permission1) { create(:permission) }
      let(:permission2) { create(:permission) }

      it 'returns an array of permission IDs' do
        role.permissions << [ permission1, permission2 ]
        ids = role.permission_list

        expect(ids).to include(permission1.id)
        expect(ids).to include(permission2.id)
        expect(ids.length).to eq(2)
      end
    end
  end

  describe 'role traits with permissions' do
    it 'creates super admin with permissions' do
      super_admin = create(:role, :super_admin_role, with_permissions: true)

      expect(super_admin.permissions.count).to be > 0
      expect(super_admin.has_permission?('Manage Users')).to be true
      expect(super_admin.has_permission?('Manage System')).to be true
    end

    it 'creates roles without permissions by default' do
      admin = create(:role, :admin_role, with_permissions: false)

      expect(admin.permissions.count).to eq(0)
    end

    it 'allows creating roles with specific permissions' do
      role = create(:role)
      permission1 = create(:permission, name: 'Custom Permission 1')
      permission2 = create(:permission, name: 'Custom Permission 2')

      role.permissions = [ permission1, permission2 ]
      role.save

      expect(role.permissions.count).to eq(2)
      expect(role.has_permission?('Custom Permission 1')).to be true
      expect(role.has_permission?('Custom Permission 2')).to be true
    end
  end
end
