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


describe Hospital do
  describe "Associations" do
    it { should have_many(:users) }
    it { should have_many(:responses) }
  end

  describe "Validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:state) }
    it { should validate_presence_of(:abbrev) }
  end

  describe "Grouping Hospitals By State" do
    it "should put the states in alphabetic order then the hospitals under then in alphabetic order" do
      rpa = create(:hospital, state: "NSW", name: "RPA").id
      royal_childrens = create(:hospital, state: "Vic", name: "The Royal Childrens Hospital").id
      campbelltown = create(:hospital, state: "NSW", name: "Campbelltown").id
      liverpool = create(:hospital, state: "NSW", name: "Liverpool").id
      mercy = create(:hospital, state: "Vic", name: "Mercy Hospital").id
      royal_ad = create(:hospital, state: "SA", name: "Royal Adelaide").id

      output = Hospital.hospitals_by_state
      expect(output.size).to eq(3)
      expect(output[0][0]).to eq("NSW")
      expect(output[1][0]).to eq("SA")
      expect(output[2][0]).to eq("Vic")

      expect(output[0][1]).to eq([["Campbelltown", campbelltown], ["Liverpool", liverpool], ["RPA", rpa]])
      expect(output[1][1]).to eq([["Royal Adelaide", royal_ad]])
      expect(output[2][1]).to eq([["Mercy Hospital", mercy], ["The Royal Childrens Hospital", royal_childrens]])
    end
  end


end
