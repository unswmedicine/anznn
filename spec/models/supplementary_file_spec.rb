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

describe SupplementaryFile do
  describe "Associations" do
    it { should belong_to(:batch_file) }
  end

  describe "Validations" do
    it { should validate_presence_of(:multi_name) }
  end
  
  describe "Validate file" do
    it "should reject binary files such as xls" do
      supplementary_file = create_supplementary_file('not_csv.xls', 'my multi')
      expect(supplementary_file.pre_process).to be false
      expect(supplementary_file.message).to eq("The supplementary file you uploaded for 'my multi' was not a valid CSV file.")
    end

    it "should reject files that are text but have malformed csv" do
      supplementary_file = create_supplementary_file('invalid_csv.csv', 'my multi')
      expect(supplementary_file.pre_process).to be false
      expect(supplementary_file.message).to eq("The supplementary file you uploaded for 'my multi' was not a valid CSV file.")
    end

    it "should reject file without a baby code column" do
      supplementary_file = create_supplementary_file('no_baby_code_column.csv', 'my multi')
      expect(supplementary_file.pre_process).to be false
      expect(supplementary_file.message).to eq("The supplementary file you uploaded for 'my multi' did not contain a BabyCODE column.")
    end

    it "should reject files that are empty" do
      # Expect the processing of the empty file to return exception.
      # This exception is raised because the PaperClip gem determines that the empty CSV is a spoofing attempt.
      expect {
        supplementary_file = create_supplementary_file('empty.csv', 'my multi')
        expect(supplementary_file.pre_process).to be false
        expect(supplementary_file.message).to eq("The supplementary file you uploaded for 'my multi' did not contain any data.")
      }.to raise_error ActiveRecord::RecordInvalid, 'Validation failed: File has contents that are not what they are reported to be'
    end

    it "should reject files that have a header row only" do
      supplementary_file = create_supplementary_file('headers_only.csv', 'my multi')
      expect(supplementary_file.pre_process).to be false
      expect(supplementary_file.message).to eq("The supplementary file you uploaded for 'my multi' did not contain any data.")
    end
  end

  describe "Denormalise file" do
    it "should take the rows from the file and stich them together as denormalised answers" do
      # this is a bit hard to express, so commenting for clarity.
      # what we're doing is taking a normalised set of answers and rearranging them to be de-normalised to suit the structure we have
      # e.g. a CSV would contain
      # | BabyCODE | SurgeryDate | SurgeryName  |
      # | B1       | 2012-12-1   | blah1        |
      # | B1       | 2012-12-2   | blah2        |
      # | B2       | 2012-12-1   | blah1        |
      # | B2       | 2012-12-2   | blah2        |
      # | B2       | 2012-12-3   | blah3        |
      # and we want to turn that into something like this
      # | BabyCODE | SurgeryDate1 | SurgeryName1  | SurgeryDate2 | SurgeryName2  | SurgeryDate3 | SurgeryName3 |
      # | B1       | 2012-12-1    | blah1         |2012-12-2     | blah2         |              |              |
      # | B2       | 2012-12-1    | blah1         |2012-12-2     | blah2         |2012-12-3     | blah3        |

      file = Rack::Test::UploadedFile.new('test_data/survey/batch_files/batch_sample_multi1.csv', 'text/csv')
      supp_file = create(:supplementary_file, multi_name: 'xyz', file: file)
      expect(supp_file.pre_process).to be true

      denormalised = supp_file.as_denormalised_hash
      #File contents:
      #BabyCODE,Date,Time
      #B1,2012-12-01,11:45
      #B1,2011-11-01,
      #B2,2011-08-30,01:05
      #B2,2010-03-04,13:23
      #B2,,11:53
      expect(denormalised.size).to eq(2)
      baby1 = denormalised['B1']
      expect(baby1).to eq({'Date1' => '2012-12-01', 'Date2' => '2011-11-01', 'Time1' => '11:45'})
      baby2 = denormalised['B2']
      expect(baby2).to eq({'Date1' => '2011-08-30', 'Date2' => '2010-03-04', 'Time1' => '01:05', 'Time2' => '13:23', 'Time3' => '11:53'})
    end
  end
  
  def create_supplementary_file(filename, multi_name)
    file = Rack::Test::UploadedFile.new('test_data/survey/batch_files/' + filename, 'text/csv')
    create(:supplementary_file, multi_name: multi_name, file: file)
  end
end
