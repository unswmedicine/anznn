# ANZNN - Australian & New Zealand Neonatal Network
# Copyright (C) 2017 Intersect Australia Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

require 'rails_helper'

describe User do
  describe "Associations" do
    it { should belong_to(:role) }
    it { should have_many(:responses) }
    it { should belong_to(:hospital) }
  end

  describe "Named Scopes" do
    describe "Users Pending Approval Scope" do
      it "should return users that are unapproved ordered by email address" do
        u1 = create(:user, :status => 'U', :email => "fasdf1@intersect.org.au")
        u2 = create(:user, :status => 'A')
        u3 = create(:user, :status => 'U', :email => "asdf1@intersect.org.au")
        u2 = create(:user, :status => 'R')
        expect(User.pending_approval).to eq([u3,u1])
      end
    end
    describe "Approved Users Scope" do
      it "should return users that are approved ordered by email address" do
        u1 = create(:user, :status => 'A', :email => "fasdf1@intersect.org.au")
        u2 = create(:user, :status => 'U')
        u3 = create(:user, :status => 'A', :email => "asdf1@intersect.org.au")
        u4 = create(:user, :status => 'R')
        u5 = create(:user, :status => 'D')
        expect(User.approved).to eq([u3,u1])
      end
    end
    describe "Deactivated or Approved Users Scope" do
      it "should return users that are approved or deactivated" do
        u1 = create(:user, :status => 'A', :email => "fasdf1@intersect.org.au")
        u2 = create(:user, :status => 'U')
        u3 = create(:user, :status => 'A', :email => "asdf1@intersect.org.au")
        u4 = create(:user, :status => 'R')
        u5 = create(:user, :status => 'D', :email => "zz@inter.org")
        expect(User.deactivated_or_approved.order(:email)).to eq([u3, u1, u5])
      end
    end
    describe "Approved Administrators Scope" do
      it "should return users that are approved ordered by email address" do
        #super_role = create(:role, :name => "Administrator")
        other_role = create(:role, :name => "Other")
        u1 = create(:super_user, :status => 'A', :email => "fasdf1@intersect.org.au")
        u2 = create(:user, :status => 'A', :role => other_role)
        u3 = create(:super_user, :status => 'U')
        u4 = create(:super_user, :status => 'R')
        u5 = create(:super_user, :status => 'D')
        expect(User.approved_superusers).to eq([u1])
      end
    end
  end

  describe "Approve Access Request" do
    it "should set the status flag to A" do
      user = create(:user, :status => 'U')
      user.approve_access_request
      expect(user.status).to eq("A")
    end
  end

  describe "Reject Access Request" do
    it "should set the status flag to R" do
      user = create(:user, :status => 'U')
      user.reject_access_request
      expect(user.status).to eq("R")
    end
  end

  describe "Status Methods" do
    context "Active" do
      it "should be active" do
        user = create(:user, :status => 'A')
        expect(user.approved?).to be true
      end
      it "should not be pending approval" do
        user = create(:user, :status => 'A')
        expect(user.pending_approval?).to be false
      end
    end

    context "Unapproved" do
      it "should not be active" do
        user = create(:user, :status => 'U')
        expect(user.approved?).to be false
      end
      it "should be pending approval" do
        user = create(:user, :status => 'U')
        expect(user.pending_approval?).to be true
      end
    end

    context "Rejected" do
      it "should not be active" do
        user = create(:user, :status => 'R')
        expect(user.approved?).to be false
      end
      it "should not be pending approval" do
        user = create(:user, :status => 'R')
        expect(user.pending_approval?).to be false
      end
    end
  end

  describe "Update password" do
    it "should fail if current password is incorrect" do
      user = create(:user, :password => "Pass.123")
      result = user.update_password({:current_password => "asdf", :password => "Pass.456", :password_confirmation => "Pass.456"})
      expect(result).to be false
      expect(user.errors[:current_password]).to eq ["is invalid"]
    end
    it "should fail if current password is blank" do
      user = create(:user, :password => "Pass.123")
      result = user.update_password({:current_password => "", :password => "Pass.456", :password_confirmation => "Pass.456"})
      expect(result).to be false
      expect(user.errors[:current_password]).to eq ["can't be blank"]
    end
    it "should fail if new password and confirmation blank" do
      user = create(:user, :password => "Pass.123")
      result = user.update_password({:current_password => "Pass.123", :password => "", :password_confirmation => ""})
      expect(result).to be false
      expect(user.errors[:password]).to eq ["can't be blank", "must be between 6 and 20 characters long and contain at least one uppercase letter, one lowercase letter, one digit and one symbol"]
    end
    it "should fail if confirmation blank" do
      user = create(:user, :password => "Pass.123")
      result = user.update_password({:current_password => "Pass.123", :password => "Pass.456", :password_confirmation => ""})
      expect(result).to be false
      expect(user.errors[:password_confirmation]).to eq ["doesn't match Password"]
    end
    it "should fail if confirmation doesn't match new password" do
      user = create(:user, :password => "Pass.123")
      result = user.update_password({:current_password => "Pass.123", :password => "Pass.456", :password_confirmation => "Pass.678"})
      expect(result).to be false
      expect(user.errors[:password_confirmation]).to eq ["doesn't match Password"]
    end
    it "should fail if password doesn't meet rules" do
      user = create(:user, :password => "Pass.123")
      result = user.update_password({:current_password => "Pass.123", :password => "Pass4567", :password_confirmation => "Pass4567"})
      expect(result).to be false
      expect(user.errors[:password]).to eq ["must be between 6 and 20 characters long and contain at least one uppercase letter, one lowercase letter, one digit and one symbol"]
    end
    it "should succeed if current password correct and new password ok" do
      user = create(:user, :password => "Pass.123")
      result = user.update_password({:current_password => "Pass.123", :password => "Pass.456", :password_confirmation => "Pass.456"})
      expect(result).to be true
    end
    it "should always blank out passwords" do
      user = create(:user, :password => "Pass.123")
      result = user.update_password({:current_password => "Pass.123", :password => "Pass.456", :password_confirmation => "Pass.456"})
      expect(user.password).to be_blank
      expect(user.password_confirmation).to be_blank
    end
  end

  describe "Find the number of superusers method" do
    it "should return true if there are at least 2 superusers" do
      user_1 = create(:super_user, :status => 'A', :email => 'user1@intersect.org.au')
      user_2 = create(:super_user, :status => 'A', :email => 'user2@intersect.org.au')
      user_3 = create(:super_user, :status => 'A', :email => 'user3@intersect.org.au')
      expect(user_1.check_number_of_superusers(1, 1)).to eq(true)
    end

    it "should return false if there is only 1 superuser" do
      user_1 = create(:super_user, :status => 'A', :email => 'user1@intersect.org.au')
      expect(user_1.check_number_of_superusers(1, 1)).to eq(false)
    end
    
    it "should return true if the logged in user does not match the user record being modified" do  
      research_role = create(:role, :name => 'Data Provider')
      user_1 = create(:super_user, :status => 'A', :email => 'user1@intersect.org.au')
      user_2 = create(:user, :role => research_role, :status => 'A', :email => 'user2@intersect.org.au')
      expect(user_1.check_number_of_superusers(1, 2)).to eq(true)
    end
  end

  describe "Validations" do
    it { should validate_presence_of :first_name }
    it { should validate_presence_of :last_name }
    it { should validate_presence_of :email }
    it { should validate_presence_of :password }

    it "should validate presence of a hospital UNLESS user has no role OR user is a super user" do
      #NB: this could also be if they are inactive instead of no role, however this works fine
      research_role = create(:role, :name => 'Data Provider')

      users = Array.new

      users << create(:super_user, :status => 'A', :email => 'user1@intersect.org.au')
      users << create(:user, :role => nil, :status => 'A', :email => 'user2@intersect.org.au')
      users << create(:user, :role => research_role, :status => 'A', :email => 'user3@intersect.org.au')

      users.each do |u|
        u.hospital = nil
      end

      expect(users[0]).to be_valid
      expect(users[1]).to be_valid
      expect(users[2]).to_not be_valid

    end

    it "should clear the hospital on before validation if a user becomes a super user" do
      super_role = create(:role, :name => Role::SUPER_USER)
      hospital = create(:hospital)
      user1 = create(:user, :status => 'A', :email => 'user1@intersect.org.au', :hospital => hospital)
      expect(user1.hospital).to eq(hospital)

      user1.role = super_role
      expect(user1).to be_valid
      expect(user1.hospital).to eq(nil)

    end

    it "should never clear the hospital for regular users" do
      hospital = create(:hospital)
      user1 = create(:user, :status => 'A', :email => 'user1@intersect.org.au', :hospital => hospital)

      expect(user1).to be_valid
      user1.save
      user1a = User.find_by_email('user1@intersect.org.au')
      expect(user1a.hospital).to eq(hospital)


    end

    #password rules: at least one lowercase, uppercase, number, symbol
    # too short < 6
    it { should_not allow_value("AB$9a").for(:password) }
    # too long > 20
    it { should_not allow_value("Aa0$56789012345678901").for(:password) }
    # missing upper
    it { should_not allow_value("aaa000$$$").for(:password) }
    # missing lower
    it { should_not allow_value("AAA000$$$").for(:password) }
    # missing digit
    it { should_not allow_value("AAAaaa$$$").for(:password) }
    # missing symbol
    it { should_not allow_value("AAA000aaa").for(:password) }
    # ok
    it { should allow_value("AB$9aa").for(:password) }

    # check each of the possible symbols we allow
    it { should allow_value("AAAaaa000!").for(:password) }
    it { should allow_value("AAAaaa000@").for(:password) }
    it { should allow_value("AAAaaa000#").for(:password) }
    it { should allow_value("AAAaaa000$").for(:password) }
    it { should allow_value("AAAaaa000%").for(:password) }
    it { should allow_value("AAAaaa000^").for(:password) }
    it { should allow_value("AAAaaa000&").for(:password) }
    it { should allow_value("AAAaaa000*").for(:password) }
    it { should allow_value("AAAaaa000(").for(:password) }
    it { should allow_value("AAAaaa000)").for(:password) }
    it { should allow_value("AAAaaa000-").for(:password) }
    it { should allow_value("AAAaaa000_").for(:password) }
    it { should allow_value("AAAaaa000+").for(:password) }
    it { should allow_value("AAAaaa000=").for(:password) }
    it { should allow_value("AAAaaa000{").for(:password) }
    it { should allow_value("AAAaaa000}").for(:password) }
    it { should allow_value("AAAaaa000[").for(:password) }
    it { should allow_value("AAAaaa000]").for(:password) }
    it { should allow_value("AAAaaa000|").for(:password) }
    it { should allow_value("AAAaaa000\\").for(:password) }
    it { should allow_value("AAAaaa000;").for(:password) }
    it { should allow_value("AAAaaa000:").for(:password) }
    it { should allow_value("AAAaaa000'").for(:password) }
    it { should allow_value("AAAaaa000\"").for(:password) }
    it { should allow_value("AAAaaa000<").for(:password) }
    it { should allow_value("AAAaaa000>").for(:password) }
    it { should allow_value("AAAaaa000,").for(:password) }
    it { should allow_value("AAAaaa000.").for(:password) }
    it { should allow_value("AAAaaa000?").for(:password) }
    it { should allow_value("AAAaaa000/").for(:password) }
    it { should allow_value("AAAaaa000~").for(:password) }
    it { should allow_value("AAAaaa000`").for(:password) }
  end

  describe "Get superuser emails" do
    it "should find all approved superusers and extract their email address" do

      admin_role = create(:role, :name => "Admin") # Testing near matches - Role::SUPER_USER => "Administrator"
      super_1 = create(:super_user, :status => "A", :email => "a@intersect.org.au")
      super_2 = create(:super_user, :status => "U", :email => "b@intersect.org.au")
      super_3 = create(:super_user, :status => "A", :email => "c@intersect.org.au")
      super_4 = create(:super_user, :status => "D", :email => "d@intersect.org.au")
      super_5 = create(:super_user, :status => "R", :email => "e@intersect.org.au")
      admin = create(:user, :role => admin_role, :status => "A", :email => "f@intersect.org.au")

      supers = User.get_superuser_emails
      expect(supers).to eq(["a@intersect.org.au", "c@intersect.org.au"])
    end
  end
  
end
