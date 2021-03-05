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
include CsvSurveyOperations

describe BatchFile do
  let(:survey) do
    question_file = Rails.root.join 'test_data/survey', 'survey_questions.csv'
    options_file = Rails.root.join 'test_data/survey', 'survey_options.csv'
    cross_question_validations_file = Rails.root.join 'test_data/survey', 'cross_question_validations.csv'
    create_survey("some_name", question_file, options_file, cross_question_validations_file)
  end
  let(:user) { create(:user) }
  let(:hospital) { create(:hospital) }

  describe "Associations" do
    it { should belong_to(:user) }
    it { should belong_to(:hospital) }
    it { should have_many(:supplementary_files) }
  end

  describe "Validations" do
    it { should validate_presence_of(:user_id) }
    it { should validate_presence_of(:survey_id) }
    it { should validate_presence_of(:hospital_id) }
    it { should validate_presence_of(:year_of_registration) }
  end

  describe "Scopes" do
    describe "Failed" do
      it "should only include failed batches" do
        d1 = create(:batch_file, status: BatchFile::STATUS_FAILED)
        create(:batch_file, status: BatchFile::STATUS_SUCCESS)
        create(:batch_file, status: BatchFile::STATUS_REVIEW)
        create(:batch_file, status: BatchFile::STATUS_IN_PROGRESS)
        d5 = create(:batch_file, status: BatchFile::STATUS_FAILED)
        expect(BatchFile.failed.collect(&:id).sort).to eq([d1.id, d5.id])
      end
    end

    describe "Older than" do
      it "should only return files older than the specified date" do
        time = Time.new(2011, 4, 14, 0, 30)
        d1 = create(:batch_file, updated_at: Time.new(2011, 4, 14, 1, 2))
        d2 = create(:batch_file, updated_at: Time.new(2011, 4, 13, 23, 59))
        d3 = create(:batch_file, updated_at: Time.new(2011, 4, 14, 0, 30))
        d4 = create(:batch_file, updated_at: Time.new(2011, 1, 1, 14, 24))
        d5 = create(:batch_file, updated_at: Time.new(2011, 4, 15, 0, 0))
        d6 = create(:batch_file, updated_at: Time.new(2011, 5, 15, 0, 0))
        expect(BatchFile.older_than(time).collect(&:id)).to eq([d2.id, d4.id])
      end
    end
  end

  describe "New object should have status set to 'In Progress'" do
    it "Should set the status on a new object" do
      expect(create(:batch_file).status).to eq("In Progress")
    end

    it "Shouldn't update status if already set" do
      expect(create(:batch_file, status: "Mine").status).to eq("Mine")
    end
  end

  describe "force_submittable?" do
    let(:batch_file) { BatchFile.new }
    it "returns true when NEEDS_REVIEW" do
      allow(batch_file).to receive(:status) { BatchFile::STATUS_REVIEW }

      expect(batch_file).to be_force_submittable
    end
    it "returns false for FAILED, SUCCESS, IN_PROGRESS" do
      [BatchFile::STATUS_FAILED, BatchFile::STATUS_SUCCESS, BatchFile::STATUS_IN_PROGRESS].each do |status|
        allow(batch_file).to receive(:status) { status }

        expect(batch_file).to_not be_force_submittable
      end
    end
  end
  describe "can't process based on status" do
    let(:batch_file) { BatchFile.new }
    it "should die trying to force successful" do
      [BatchFile::STATUS_FAILED, BatchFile::STATUS_SUCCESS, BatchFile::STATUS_IN_PROGRESS].each do |status|
        allow(batch_file).to receive(:status) { status }

        if status == BatchFile::STATUS_IN_PROGRESS
          # Batch process explicitly raises error unless status is in progress. When in progress, this will raise
          #  type error due to no file being attached to the batch file object
          expect { batch_file.process }.to raise_error('no implicit conversion of nil into String')
          expect { batch_file.process(:force) }.to raise_error('no implicit conversion of nil into String')
        else
          expect { batch_file.process }.to raise_error("Batch has already been processed, cannot reprocess")
          expect { batch_file.process(:force) }.to raise_error("Batch has already been processed, cannot reprocess")
        end

      end
    end
    it "should needs_review" do
      allow(batch_file).to receive(:status) { BatchFile::STATUS_REVIEW }
      expect { batch_file.process }.to raise_error("Batch has already been processed, cannot reprocess")
    end
  end

  #These are integration tests that verify the file processing works correctly
  describe "File processing" do

    describe "invalid files" do
      it "should reject binary files such as xls" do
        batch_file = process_batch_file('not_csv.xls', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded was not a valid CSV file. Processing stopped on CSV row 0")
        expect(batch_file.record_count).to be_nil
        expect(batch_file.problem_record_count).to be_nil
        expect(batch_file.summary_report_path).to be_nil
        expect(batch_file.detail_report_path).to be_nil
      end

      it "should reject files that are text but have malformed csv" do
        batch_file = process_batch_file('invalid_csv.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded was not a valid CSV file. Processing stopped on CSV row 2")
        expect(batch_file.record_count).to be_nil
        expect(batch_file.problem_record_count).to be_nil
        expect(batch_file.summary_report_path).to be_nil
        expect(batch_file.detail_report_path).to be_nil
      end

      it "should reject file without a baby code column" do
        batch_file = process_batch_file('no_baby_code_column.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded did not contain a BabyCODE column. Processing stopped on CSV row 0")
        expect(batch_file.record_count).to be_nil
        expect(batch_file.problem_record_count).to be_nil
        expect(batch_file.summary_report_path).to be_nil
        expect(batch_file.detail_report_path).to be_nil
      end

      it "should reject files that are empty" do
        # Expect the processing of the empty file to return exception.
        # This exception is raised because the PaperClip gem determines that the empty CSV is a spoofing attempt.
        expect {
          batch_file = process_batch_file('empty.csv', survey, user)
          expect(batch_file.status).to eq("Failed")
          expect(batch_file.message).to eq("The file you uploaded did not contain any data.")
          expect(batch_file.record_count).to be_nil
          expect(batch_file.problem_record_count).to be_nil
          expect(batch_file.summary_report_path).to be_nil
          expect(batch_file.detail_report_path).to be_nil
        }.to raise_error ActiveRecord::RecordInvalid, 'Validation failed: File has contents that are not what they are reported to be'
      end

      it "should reject files that have a header row only" do
        batch_file = process_batch_file('headers_only.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded did not contain any data.")
        expect(batch_file.record_count).to be_nil
        expect(batch_file.problem_record_count).to be_nil
        expect(batch_file.summary_report_path).to be_nil
        expect(batch_file.detail_report_path).to be_nil
      end
    end

    describe "well formatted files" do
      it "file with no errors or warnings - should create the survey responses and answers" do
        batch_file = process_batch_file('no_errors_or_warnings.csv', survey, user, 2008)
        expect(batch_file.organised_problems.detailed_problems).to eq []
        expect(batch_file.status).to eq("Processed Successfully")
        expect(batch_file.message).to eq("Your file has been processed successfully.")
        expect(Response.count).to eq 3
        expect(Answer.count).to eq(21) #3x8 questions = 24, 3 not answered
        expect(batch_file.problem_record_count).to eq 0
        expect(batch_file.record_count).to eq 3

        r1 = Response.find_by_baby_code!("B1")
        r2 = Response.find_by_baby_code!("B2")
        r3 = Response.find_by_baby_code!("B3")

        [r1, r2, r3].each do |r|
          expect(r.survey).to eq(survey)
          expect(r.user).to eq(user)
          expect(r.hospital).to eq(hospital)
          expect(r.submitted_status).to eq(Response::STATUS_SUBMITTED)
          expect(r.batch_file.id).to eq(batch_file.id)
          expect(r.year_of_registration).to eq(2008)
        end

        answer_hash = r1.answers.reduce({}) { |hash, answer| hash[answer.question.code] = answer; hash }
        expect(answer_hash["TextMandatory"].text_answer).to eq "B1Val1"
        expect(answer_hash["TextOptional"]).to be_nil #not answered
        expect(answer_hash["Date1"].date_answer).to eq Date.parse("2011-12-25")
        expect(answer_hash["Time"].time_answer).to eq Time.utc(2000, 1, 1, 14, 30)
        expect(answer_hash["Choice"].choice_answer).to eq "0"
        expect(answer_hash["Decimal"].decimal_answer).to eq 56.77
        expect(answer_hash["Integer"].integer_answer).to eq 10
        Answer.all.each { |a| expect(a.has_fatal_warning?).to be false }
        Answer.all.each { |a| expect(a.has_warning?).to be false }
        expect(batch_file.record_count).to eq 3
                                   # summary report should exist but not detail report
        expect(batch_file.summary_report_path).to_not be_nil
        expect(File.exist?(batch_file.summary_report_path)).to be true
        expect(batch_file.detail_report_path).to be_nil
      end

      it "file with no errors or warnings - should create the survey responses and answers and should strip leading/trailing whitespace" do
        batch_file = process_batch_file('no_errors_or_warnings_whitespace.csv', survey, user)
        expect(batch_file.status).to eq("Processed Successfully")
        expect(batch_file.message).to eq("Your file has been processed successfully.")
        expect(Response.count).to eq 3
        expect(Answer.count).to eq(21) #3x8 questions = 24, 3 not answered
        expect(batch_file.problem_record_count).to eq 0
        expect(batch_file.record_count).to eq 3

        r1 = Response.find_by_baby_code!("B1")
        r2 = Response.find_by_baby_code!("B2")
        r3 = Response.find_by_baby_code!("B3")

        [r1, r2, r3].each do |r|
          expect(r.survey).to eq(survey)
          expect(r.user).to eq(user)
          expect(r.hospital).to eq(hospital)
          expect(r.submitted_status).to eq(Response::STATUS_SUBMITTED)
          expect(r.batch_file.id).to eq(batch_file.id)
        end

        answer_hash = r1.answers.reduce({}) { |hash, answer| hash[answer.question.code] = answer; hash }
        expect(answer_hash["TextMandatory"].text_answer).to eq "B1Val1"
        expect(answer_hash["TextOptional"]).to be_nil #not answered
        expect(answer_hash["Date1"].date_answer).to eq Date.parse("2011-12-25")
        expect(answer_hash["Time"].time_answer).to eq Time.utc(2000, 1, 1, 14, 30)
        expect(answer_hash["Choice"].choice_answer).to eq "0"
        expect(answer_hash["Decimal"].decimal_answer).to eq 56.77
        expect(answer_hash["Integer"].integer_answer).to eq 10
        Answer.all.each { |a| expect(a.has_fatal_warning?).to be false }
        Answer.all.each { |a| expect(a.has_warning?).to be false }
        expect(batch_file.record_count).to eq 3
                                   # summary report should exist but not detail report
        expect(batch_file.summary_report_path).to_not be_nil
        expect(File.exist?(batch_file.summary_report_path)).to be true
        expect(batch_file.detail_report_path).to be_nil
      end
    end

    describe "with validation errors" do
      it "file that just has blank rows fails on baby code since baby codes are missing" do
        batch_file = process_batch_file('blank_rows.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded is missing one or more baby codes. Each record must have a baby code. Processing stopped on CSV row 1")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to be_nil
        expect(batch_file.problem_record_count).to be_nil
        expect(batch_file.summary_report_path).to be_nil
        expect(batch_file.detail_report_path).to be_nil
      end

      it "file with missing baby codes should be rejected completely and no reports generated" do
        batch_file = process_batch_file('missing_baby_code.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded is missing one or more baby codes. Each record must have a baby code. Processing stopped on CSV row 2")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to be_nil
        expect(batch_file.problem_record_count).to be_nil
        expect(batch_file.summary_report_path).to be_nil
        expect(batch_file.detail_report_path).to be_nil
      end

      it "file with duplicate baby codes within the file should be rejected completely and no reports generated" do
        batch_file = process_batch_file('duplicate_baby_code.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded contained duplicate baby codes. Each baby code can only be used once. Processing stopped on CSV row 3")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to be_nil
        expect(batch_file.problem_record_count).to be_nil
        expect(batch_file.summary_report_path).to be_nil
        expect(batch_file.detail_report_path).to be_nil
      end

      it "file with duplicate baby codes within the file (with whitespace padding) should be rejected completely and no reports generated" do
        batch_file = process_batch_file('duplicate_baby_code_whitespace.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded contained duplicate baby codes. Each baby code can only be used once. Processing stopped on CSV row 3")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to be_nil
        expect(batch_file.problem_record_count).to be_nil
        expect(batch_file.summary_report_path).to be_nil
        expect(batch_file.detail_report_path).to be_nil
      end

      it "should reject records with missing mandatory fields" do
        batch_file = process_batch_file('missing_mandatory_fields.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded did not pass validation. Please review the reports for details.")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.summary_report_path).to_not be_nil
        expect(batch_file.detail_report_path).to_not be_nil
      end

      it "should reject records with missing mandatory fields - where the column is missing entirely" do
        batch_file = process_batch_file('missing_mandatory_column.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded did not pass validation. Please review the reports for details.")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.summary_report_path).to_not be_nil
        expect(batch_file.detail_report_path).to_not be_nil
      end

      it "should reject records with choice answers that are not one of the allowed values for the question" do
        batch_file = process_batch_file('incorrect_choice_answer_value.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded did not pass validation. Please review the reports for details.")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.summary_report_path).to_not be_nil
        expect(batch_file.detail_report_path).to_not be_nil
      end

      it "should reject records with integer answers that are badly formed" do
        batch_file = process_batch_file('bad_integer.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded did not pass validation. Please review the reports for details.")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.summary_report_path).to_not be_nil
        expect(batch_file.detail_report_path).to_not be_nil
      end

      it "should reject records with decimal answers that are badly formed" do
        batch_file = process_batch_file('bad_decimal.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded did not pass validation. Please review the reports for details.")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.summary_report_path).to_not be_nil
        expect(batch_file.detail_report_path).to_not be_nil
      end

      it "should reject records with time answers that are badly formed" do
        batch_file = process_batch_file('bad_time.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded did not pass validation. Please review the reports for details.")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.summary_report_path).to_not be_nil
        expect(batch_file.detail_report_path).to_not be_nil
      end

      it "should reject records with date answers that are badly formed" do
        batch_file = process_batch_file('bad_date.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded did not pass validation. Please review the reports for details.")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.summary_report_path).to_not be_nil
        expect(batch_file.detail_report_path).to_not be_nil
      end

      it "should reject records where the baby code is already in the system" do
        create(:response, survey: survey, baby_code: "B2")
        batch_file = process_batch_file('no_errors_or_warnings.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded did not pass validation. Please review the reports for details.")
        expect(Response.count).to eq 1 #the one we created earlier
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.problem_record_count).to eq 1
        expect(batch_file.detail_report_path).to_not be_nil
        expect(File.exist?(batch_file.summary_report_path)).to be true

        csv_file = batch_file.detail_report_path
        rows = CSV.read(csv_file)
        expect(rows.size).to eq(2)
        expect(rows[0]).to eq(["BabyCODE", "Column Name", "Type", "Value", "Message"])
        expect(rows[1]).to eq(['B2', 'BabyCODE', 'Error', 'B2', 'Baby code B2 has already been used.'])
      end

      it "should reject records where the baby code is already in the system even with whitespace padding" do
        create(:response, survey: survey, baby_code: "B2")
        batch_file = process_batch_file('no_errors_or_warnings_whitespace.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded did not pass validation. Please review the reports for details.")
        expect(Response.count).to eq 1 #the one we created earlier
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.problem_record_count).to eq 1
        expect(batch_file.detail_report_path).to_not be_nil
        expect(File.exist?(batch_file.summary_report_path)).to be true

        csv_file = batch_file.detail_report_path
        rows = CSV.read(csv_file)
        expect(rows.size).to eq(2)
        expect(rows[0]).to eq(["BabyCODE", "Column Name", "Type", "Value", "Message"])
        expect(rows[1]).to eq(['B2', 'BabyCODE', 'Error', 'B2', 'Baby code B2 has already been used.'])
      end

      it "can detect both duplicate baby code and other errors on the same record" do
        create(:response, survey: survey, baby_code: "B2")
        batch_file = process_batch_file('missing_mandatory_fields.csv', survey, user)
        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded did not pass validation. Please review the reports for details.")
        expect(Response.count).to eq 1 #the one we created earlier
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.problem_record_count).to eq 1
        expect(batch_file.detail_report_path).to_not be_nil
        expect(File.exist?(batch_file.summary_report_path)).to be true

        csv_file = batch_file.detail_report_path
        rows = CSV.read(csv_file)
        expect(rows.size).to eq(3)
        expect(rows[0]).to eq(["BabyCODE", "Column Name", "Type", "Value", "Message"])
        expect(rows[1]).to eq(['B2', 'BabyCODE', 'Error', 'B2', 'Baby code B2 has already been used.'])
        expect(rows[2]).to eq(['B2', 'TextMandatory', 'Error', '', 'This question is mandatory'])
      end
    end

    describe "with warnings" do
      it "warns on number range issues" do
        batch_file = process_batch_file('number_out_of_range.csv', survey, user)
        expect(batch_file.status).to eq("Needs Review")
        expect(batch_file.message).to eq("The file you uploaded has one or more warnings. Please review the reports for details.")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.problem_record_count).to eq 1
        expect(batch_file.summary_report_path).to_not be_nil
        expect(batch_file.detail_report_path).to_not be_nil
      end

      it "accepts number range issues if forced to" do
        # sad path covered earlier
        batch_file = BatchFile.create!(file: Rack::Test::UploadedFile.new('test_data/survey/batch_files/number_out_of_range.csv', 'text/csv'), survey: survey, user: user, hospital: hospital, year_of_registration: 2009)
        batch_file.process
        batch_file.reload

        expect(batch_file.status).to eq("Needs Review")
        expect(batch_file.message).to eq("The file you uploaded has one or more warnings. Please review the reports for details.")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.problem_record_count).to eq 1
        expect(batch_file.summary_report_path).to_not be_nil
        expect(batch_file.detail_report_path).to_not be_nil

        batch_file.status = BatchFile::STATUS_IN_PROGRESS # the controller sets it to in progress before forcing processing
        batch_file.process(:force)
        batch_file.reload

        expect(batch_file.status).to eq("Processed Successfully")
        expect(batch_file.message).to eq("Your file has been processed successfully.")
        expect(Response.count).to eq 3
        expect(Answer.count).to eq 20
        expect(batch_file.record_count).to eq 3
        expect(batch_file.problem_record_count).to eq 1
        expect(batch_file.summary_report_path).to_not be_nil
        expect(batch_file.detail_report_path).to_not be_nil

      end

      it "should warn on records which fail cross-question validations" do
        batch_file = process_batch_file('cross_question_error.csv', survey, user)
        expect(batch_file.status).to eq("Needs Review")
        expect(batch_file.message).to eq("The file you uploaded has one or more warnings. Please review the reports for details.")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.problem_record_count).to eq 1
        expect(batch_file.summary_report_path).to_not be_nil
        expect(batch_file.detail_report_path).to_not be_nil

        csv_file = batch_file.detail_report_path
        rows = CSV.read(csv_file)
        expect(rows.size).to eq(2)
        expect(rows[0]).to eq(['BabyCODE', 'Column Name', 'Type', 'Value', 'Message'])
        expect(rows[1]).to eq(['B3', 'Date1', 'Warning', '2010-05-29', 'D1 must be >= D2'])
      end

      it "should accepts cross-question validation failures if forced to" do
        batch_file = process_batch_file('cross_question_error.csv', survey, user)
        expect(batch_file.status).to eq("Needs Review")
        expect(batch_file.message).to eq("The file you uploaded has one or more warnings. Please review the reports for details.")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.problem_record_count).to eq 1
        expect(batch_file.summary_report_path).to_not be_nil
        expect(batch_file.detail_report_path).to_not be_nil

        batch_file.status = BatchFile::STATUS_IN_PROGRESS # the controller sets it to in progress before forcing processing
        batch_file.process(:force)
        batch_file.reload

        expect(batch_file.status).to eq("Processed Successfully")
        expect(batch_file.message).to eq("Your file has been processed successfully.")
        expect(Response.count).to eq 3
        expect(Answer.count).to eq 21
        expect(batch_file.record_count).to eq 3
        expect(batch_file.problem_record_count).to eq 1
        expect(batch_file.summary_report_path).to_not be_nil
        expect(batch_file.detail_report_path).to_not be_nil
      end

      it "should warn on records which fail cross-question validations - date time quad failure" do
        batch_file = process_batch_file('cross_question_error_datetime_comparison.csv', survey, user)
        expect(batch_file.status).to eq("Needs Review")
        expect(batch_file.message).to eq("The file you uploaded has one or more warnings. Please review the reports for details.")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.problem_record_count).to eq 1
        expect(batch_file.summary_report_path).to_not be_nil
        expect(batch_file.detail_report_path).to_not be_nil
        expect(File.exist?(batch_file.summary_report_path)).to be true

        csv_file = batch_file.detail_report_path
        rows = CSV.read(csv_file)
        expect(rows.size).to eq(2)
        expect(rows[0]).to eq(['BabyCODE', 'Column Name', 'Type', 'Value', 'Message'])
        expect(rows[1]).to eq(['B3', 'Date1', 'Warning', '2010-05-29', 'D1+T1 must be > D2+T2'])
      end


    end

    describe "with a range of errors and warnings" do
      it "should produce a CSV detail report file with correct error and warning details" do
        batch_file = process_batch_file('a_range_of_problems.csv', survey, user)

        expect(batch_file.status).to eq("Failed")
        expect(batch_file.message).to eq("The file you uploaded did not pass validation. Please review the reports for details.")
        expect(Response.count).to eq 0
        expect(Answer.count).to eq 0
        expect(batch_file.record_count).to eq 3
        expect(batch_file.problem_record_count).to eq 3

        csv_file = batch_file.detail_report_path
        rows = CSV.read(csv_file)
        expect(rows.size).to eq(7)
        expect(rows[0]).to eq(["BabyCODE", "Column Name", "Type", "Value", "Message"])
        expect(rows[1]).to eq(['B1', 'Date1', 'Error', '2011-ab-25', 'Answer is invalid (must be a valid date)'])
        expect(rows[2]).to eq(['B1', 'Decimal', 'Error', 'a.77', 'Answer is the wrong format (expected a decimal number)'])
        expect(rows[3]).to eq(['B1', 'TextMandatory', 'Error', '', 'This question is mandatory'])
        expect(rows[4]).to eq(['B2', 'Integer', 'Warning', '3', 'Answer should be at least 5'])
        expect(rows[5]).to eq(['B2', 'Time', 'Error', 'ab:59', 'Answer is invalid (must be a valid time)'])
        expect(rows[6]).to eq(['B3', 'Date1', 'Warning', '2010-05-29', 'D1 must be >= D2'])

        expect(File.exist?(batch_file.summary_report_path)).to be true
      end
    end

    describe "processing supplementary files" do
      let(:survey_with_multis) do
        question_file = Rails.root.join 'test_data/survey', 'survey_questions_with_multi.csv'
        options_file = Rails.root.join 'test_data/survey', 'survey_options.csv'
        cross_question_validations_file = Rails.root.join 'test_data/survey', 'cross_question_validations_with_multi.csv'
        create_survey("with multi", question_file, options_file, cross_question_validations_file)
      end

      describe "valid file" do
        it "should add the data from the supplementary files to the dataset" do
          batch_file = process_batch_file_with_supplementaries('no_errors_or_warnings_multi.csv', user, {'Multi1' => 'batch_sample_multi1.csv', 'Multi2' => 'batch_sample_multi2.csv'})
          expect(batch_file.status).to eq("Processed Successfully")

          expect(Response.count).to eq 3
          #Answer.count.should eq(30) #14 regular + 16 from supplementary files = 31
          expect(batch_file.problem_record_count).to eq 0
          expect(batch_file.record_count).to eq 3

          b1_answer_hash = Response.find_by_baby_code!("B1").answers.reduce({}) { |hash, answer| hash[answer.question.code] = answer; hash }
          b2_answer_hash = Response.find_by_baby_code!("B2").answers.reduce({}) { |hash, answer| hash[answer.question.code] = answer; hash }
          b3_answer_hash = Response.find_by_baby_code!("B3").answers.reduce({}) { |hash, answer| hash[answer.question.code] = answer; hash }

          expect(b1_answer_hash.size).to eq(7) #3 from multi-1, 0 from multi-2, 4 from main
          expect(b1_answer_hash["Date1"].date_answer).to eq Date.parse("2012-12-01")
          expect(b1_answer_hash["Date2"].date_answer).to eq Date.parse("2011-11-01")
          expect(b1_answer_hash["Time1"].time_answer).to eq Time.utc(2000, 1, 1, 11, 45)
          expect(b1_answer_hash["TextMandatory"].text_answer).to eq "B1Val1"
          expect(b1_answer_hash["Choice"].choice_answer).to eq "0"
          expect(b1_answer_hash["Decimal"].decimal_answer).to eq 56.77
          expect(b1_answer_hash["Integer"].integer_answer).to eq 10

          expect(b2_answer_hash.size).to eq(16) #5 from multi-1, 6 from multi-2, 5 from main
          expect(b2_answer_hash["MultiText1"].text_answer).to eq "text-answer-1-b2"
          expect(b2_answer_hash["MultiText2"].text_answer).to eq "text-answer-2-b2"
          expect(b2_answer_hash["MultiText3"].text_answer).to eq "text-answer-3-b2"
          expect(b2_answer_hash["MultiNumber1"].integer_answer).to eq 1
          expect(b2_answer_hash["MultiNumber2"].integer_answer).to eq 2
          expect(b2_answer_hash["MultiNumber3"].integer_answer).to eq 3

          expect(b3_answer_hash.size).to eq(7) #0 from multi-1, 2 from multi-2, 5 from main

          expect(batch_file.record_count).to eq 3
        end
      end

      describe "invalid files" do
        # the various possible invalid file cases are tested in supplementary_file_spec, so here we're just testing that batch_file processing
        # fails if one of the supplementaries is invalid
        it "should stop on the first bad file" do
          batch_file = process_batch_file_with_supplementaries('no_errors_or_warnings_multi.csv', user, {'Multi1' => 'batch_sample_multi1.csv', 'Multi2' => 'not_csv.xls'})
          expect(batch_file.status).to eq("Failed")
          expect(batch_file.message).to eq("The supplementary file you uploaded for 'Multi2' was not a valid CSV file.")
        end
      end

      describe "with validation errors from the supplementary files" do
        # there's not really any special behaviour here, the answers are validated just like anything else, so we just test one example
        it "should reject records with integer answers that are badly formed" do
          batch_file = process_batch_file_with_supplementaries('no_errors_or_warnings_multi.csv', user, {'Multi1' => 'batch_sample_multi1_errors.csv', 'Multi2' => 'batch_sample_multi2.csv'})
          expect(batch_file.status).to eq("Failed")
          expect(batch_file.message).to eq("The file you uploaded did not pass validation. Please review the reports for details.")
          expect(Response.count).to eq 0
          expect(Answer.count).to eq 0
          expect(batch_file.record_count).to eq 3
          expect(batch_file.summary_report_path).to_not be_nil
          expect(batch_file.detail_report_path).to_not be_nil
        end

      end

      describe "where the number of possible answers is exceeded" do
        pending
      end

      describe "where the supplementary file contains baby codes not in the main file" do
        pending
      end

      describe "where the supplementary file contains extra unwanted info" do
        pending
      end
    end

  end

  describe "Destroy" do
    it "should remove the associated data file and any reports" do
      batch_file = process_batch_file('a_range_of_problems.csv', survey, user)
      path = batch_file.file.path
      summary_path = batch_file.summary_report_path
      detail_path = batch_file.detail_report_path

      expect(path).to_not be_nil
      expect(summary_path).to_not be_nil
      expect(detail_path).to_not be_nil

      expect(File.exist?(path)).to be true
      expect(File.exist?(summary_path)).to be true
      expect(File.exist?(detail_path)).to be true

      batch_file.destroy
      expect(File.exist?(path)).to be false
      expect(File.exist?(summary_path)).to be false
      expect(File.exist?(detail_path)).to be false
    end
  end

  def process_batch_file(file_name, survey, user, year_of_registration=2009)
    batch_file = BatchFile.create!(file: Rack::Test::UploadedFile.new('test_data/survey/batch_files/' + file_name, 'text/csv'), survey: survey, user: user, hospital: hospital, year_of_registration: year_of_registration)
    batch_file.process
    batch_file.reload
    batch_file
  end

  def process_batch_file_with_supplementaries(file_name, user, supp_files)
    batch_file = BatchFile.create!(file: Rack::Test::UploadedFile.new('test_data/survey/batch_files/' + file_name, 'text/csv'), survey: survey_with_multis, user: user, hospital: hospital, year_of_registration: 2009)
    supp_files.each_pair do |multi_name, supp_file_name|
      file = Rack::Test::UploadedFile.new('test_data/survey/batch_files/' + supp_file_name, 'text/csv')
      batch_file.supplementary_files.create!(multi_name: multi_name, file: file)
    end
    batch_file.process
    batch_file.reload
    batch_file
  end
end

