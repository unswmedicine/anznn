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

describe ConfigurationItem do
  describe "Validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:configuration_value) }
  end
  
  describe "Get year of registration range" do
    it "should get the start and end years from the config table" do
      create(:configuration_item, name: ConfigurationItem::YEAR_OF_REGISTRATION_START, configuration_value: "2005")
      create(:configuration_item, name: ConfigurationItem::YEAR_OF_REGISTRATION_END, configuration_value: "2012")
      
      expect(ConfigurationItem.year_of_registration_range).to eq((2005..2012).to_a)
    end
  end
end
