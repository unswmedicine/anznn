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

describe StringLengthValidator do

  describe "Validating a range" do
    let(:question) { create(:question, string_min: 5, string_max: 15) }

    it "should return true if in range" do
      expect(StringLengthValidator.validate(question, "12345")).to eq([true, nil])
      expect(StringLengthValidator.validate(question, "123456")).to eq([true, nil])
      expect(StringLengthValidator.validate(question, "123456789012345")).to eq([true, nil])
    end

    it "should return false it outside range" do
      expect(StringLengthValidator.validate(question, "1")).to eq([false, "Answer should be between 5 and 15 characters"])
      expect(StringLengthValidator.validate(question, "1234")).to eq([false, "Answer should be between 5 and 15 characters"])
      expect(StringLengthValidator.validate(question, "1234567890123456")).to eq([false, "Answer should be between 5 and 15 characters"])
    end
  end

  describe "Validating a range with same min/max" do
    let(:question) { create(:question, string_min: 5, string_max: 5) }

    it "should return true if in range" do
      expect(StringLengthValidator.validate(question, "12345")).to eq([true, nil])
    end

    it "should return false it outside range" do
      expect(StringLengthValidator.validate(question, "1234")).to eq([false, "Answer should be 5 characters"])
      expect(StringLengthValidator.validate(question, "123456")).to eq([false, "Answer should be 5 characters"])
    end
  end

  describe "Validating min only" do
    let(:question) { create(:question, string_min: 5, string_max: nil) }

    it "should return true if in range" do
      expect(StringLengthValidator.validate(question, "12345")).to eq([true, nil])
      expect(StringLengthValidator.validate(question, "123456")).to eq([true, nil])
      expect(StringLengthValidator.validate(question, "123456789012345")).to eq([true, nil])
    end

    it "should return false it outside range" do
      expect(StringLengthValidator.validate(question, "1")).to eq([false, "Answer should be at least 5 characters"])
      expect(StringLengthValidator.validate(question, "1234")).to eq([false, "Answer should be at least 5 characters"])
    end
  end

  describe "Validating max only" do
    let(:question) { create(:question, string_min: nil, string_max: 15) }

    it "should return true if in range" do
      expect(StringLengthValidator.validate(question, "1")).to eq([true, nil])
      expect(StringLengthValidator.validate(question, "1456")).to eq([true, nil])
      expect(StringLengthValidator.validate(question, "123456789012345")).to eq([true, nil])
    end

    it "should return false it outside range" do
      expect(StringLengthValidator.validate(question, "1234567890123456")).to eq([false, "Answer should be a maximum of 15 characters"])
    end
  end

  describe "Validating on a question with no range" do
    it "should always return true" do
      question = create(:question, string_min: nil, string_max: nil)
      expect(StringLengthValidator.validate(question, "abc")).to eq([true, nil])
    end
  end

  describe "Validating a nil or blank answer" do
    it "should always return true" do
      question = create(:question, string_min: 1, string_max: 5)
      #blank / nil are not considered errors
      expect(StringLengthValidator.validate(question, nil)).to eq([true, nil])
      expect(StringLengthValidator.validate(question, "")).to eq([true, nil])
    end
  end
end
