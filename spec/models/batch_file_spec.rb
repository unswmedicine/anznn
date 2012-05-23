require 'spec_helper'
include CsvSurveyOperations

describe BatchFile do
  describe "Associations" do
    it { should belong_to(:user) }
    it { should belong_to(:survey) }
    it { should belong_to(:hospital) }
  end

  describe "Validations" do
    it { should validate_presence_of(:user_id) }
    it { should validate_presence_of(:survey_id) }
    it { should validate_presence_of(:hospital_id) }
    it { should validate_presence_of(:year_of_registration) }
  end

  describe "New object should have status set to 'In Progress'" do
    it "Should set the status on a new object" do
      Factory(:batch_file).status.should eq("In Progress")
    end

    it "Shouldn't update status if already set" do
      Factory(:batch_file, status: "Mine").status.should eq("Mine")
    end
  end

  describe "force_submittable?" do
    let(:batch_file) { BatchFile.new }
    it "returns true when NEEDS_REVIEW" do
      batch_file.stub(:status) { BatchFile::STATUS_REVIEW }

      batch_file.should be_force_submittable
    end
    it "returns false for FAILED, SUCCESS, IN_PROGRESS" do
      [BatchFile::STATUS_FAILED, BatchFile::STATUS_SUCCESS, BatchFile::STATUS_IN_PROGRESS].each do |status|
        batch_file.stub(:status) { status }

        batch_file.should_not be_force_submittable
      end
    end
  end
  describe "can't process based on status" do
    let(:batch_file) { BatchFile.new }
    it "should die trying to force successful" do
      [BatchFile::STATUS_FAILED, BatchFile::STATUS_SUCCESS, BatchFile::STATUS_IN_PROGRESS].each do |status|
        batch_file.stub(:status) { status }

        expect { batch_file.process }.should raise_error
        expect { batch_file.process(:force) }.should raise_error
      end
    end
    it "should needs_review" do
      batch_file.stub(:status) { BatchFile::STATUS_REVIEW }
      expect { batch_file.process }.should raise_error
    end
  end

  #These are integration tests that verify the file processing works correctly
  describe "File processing" do
    let(:survey) do
      question_file = Rails.root.join 'test_data/survey', 'survey_questions.csv'
      options_file = Rails.root.join 'test_data/survey', 'survey_options.csv'
      cross_question_validations_file = Rails.root.join 'test_data/survey', 'cross_question_validations.csv'
      create_survey("some_name", question_file, options_file, cross_question_validations_file)
    end
    let(:user) { Factory(:user) }
    let(:hospital) { Factory(:hospital) }

    describe "Invalid files" do
      it "should reject binary files such as xls" do
        batch_file = process_batch_file('not_csv.xls', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded was not a valid CSV file. Processing stopped on CSV row 0")
        batch_file.record_count.should be_nil
        batch_file.problem_record_count.should be_nil
        batch_file.summary_report_path.should be_nil
        batch_file.detail_report_path.should be_nil
      end

      it "should reject files that are text but have malformed csv" do
        batch_file = process_batch_file('invalid_csv.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded was not a valid CSV file. Processing stopped on CSV row 2")
        batch_file.record_count.should be_nil
        batch_file.problem_record_count.should be_nil
        batch_file.summary_report_path.should be_nil
        batch_file.detail_report_path.should be_nil
      end

      it "should reject file without a baby code column" do
        batch_file = process_batch_file('no_baby_code_column.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not contain a BabyCode column. Processing stopped on CSV row 0")
        batch_file.record_count.should be_nil
        batch_file.problem_record_count.should be_nil
        batch_file.summary_report_path.should be_nil
        batch_file.detail_report_path.should be_nil
      end

      it "should reject files that are empty" do
        batch_file = process_batch_file('empty.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not contain any data.")
        batch_file.record_count.should be_nil
        batch_file.problem_record_count.should be_nil
        batch_file.summary_report_path.should be_nil
        batch_file.detail_report_path.should be_nil
      end

      it "should reject files that have a header row only" do
        batch_file = process_batch_file('headers_only.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not contain any data.")
        batch_file.record_count.should be_nil
        batch_file.problem_record_count.should be_nil
        batch_file.summary_report_path.should be_nil
        batch_file.detail_report_path.should be_nil
      end
    end

    describe "Well formatted files" do
      it "file with no errors or warnings - should create the survey responses and answers" do
        batch_file = process_batch_file('no_errors_or_warnings.csv', survey, user, 2008)
        batch_file.status.should eq("Processed Successfully")
        batch_file.message.should eq("Your file has been processed successfully.")
        Response.count.should == 3
        Answer.count.should eq(21) #3x8 questions = 24, 3 not answered
        batch_file.problem_record_count.should == 0
        batch_file.record_count.should == 3

        r1 = Response.find_by_baby_code!("B1")
        r2 = Response.find_by_baby_code!("B2")
        r3 = Response.find_by_baby_code!("B3")

        [r1, r2, r3].each do |r|
          r.survey.should eq(survey)
          r.user.should eq(user)
          r.hospital.should eq(hospital)
          r.submitted_status.should eq(Response::STATUS_SUBMITTED)
          r.batch_file.id.should eq(batch_file.id)
          r.year_of_registration.should eq(2008)
        end

        answer_hash = r1.answers.reduce({}) { |hash, answer| hash[answer.question.code] = answer; hash }
        answer_hash["TextMandatory"].text_answer.should == "B1Val1"
        answer_hash["TextOptional"].should be_nil #not answered
        answer_hash["Date1"].date_answer.should == Date.parse("2011-12-25")
        answer_hash["Time"].time_answer.should == Time.utc(2000, 1, 1, 14, 30)
        answer_hash["Choice"].choice_answer.should == "0"
        answer_hash["Decimal"].decimal_answer.should == 56.77
        answer_hash["Integer"].integer_answer.should == 10
        Answer.all.each { |a| a.has_fatal_warning?.should be_false }
        Answer.all.each { |a| a.has_warning?.should be_false }
        batch_file.record_count.should == 3
                                   # summary report should exist but not detail report
        batch_file.summary_report_path.should_not be_nil
        File.exist?(batch_file.summary_report_path).should be_true
        batch_file.detail_report_path.should be_nil
      end

      it "file with no errors or warnings - should create the survey responses and answers and should strip leading/trailing whitespace" do
        batch_file = process_batch_file('no_errors_or_warnings_whitespace.csv', survey, user)
        batch_file.status.should eq("Processed Successfully")
        batch_file.message.should eq("Your file has been processed successfully.")
        Response.count.should == 3
        Answer.count.should eq(21) #3x8 questions = 24, 3 not answered
        batch_file.problem_record_count.should == 0
        batch_file.record_count.should == 3

        r1 = Response.find_by_baby_code!("B1")
        r2 = Response.find_by_baby_code!("B2")
        r3 = Response.find_by_baby_code!("B3")

        [r1, r2, r3].each do |r|
          r.survey.should eq(survey)
          r.user.should eq(user)
          r.hospital.should eq(hospital)
          r.submitted_status.should eq(Response::STATUS_SUBMITTED)
          r.batch_file.id.should eq(batch_file.id)
        end

        answer_hash = r1.answers.reduce({}) { |hash, answer| hash[answer.question.code] = answer; hash }
        answer_hash["TextMandatory"].text_answer.should == "B1Val1"
        answer_hash["TextOptional"].should be_nil #not answered
        answer_hash["Date1"].date_answer.should == Date.parse("2011-12-25")
        answer_hash["Time"].time_answer.should == Time.utc(2000, 1, 1, 14, 30)
        answer_hash["Choice"].choice_answer.should == "0"
        answer_hash["Decimal"].decimal_answer.should == 56.77
        answer_hash["Integer"].integer_answer.should == 10
        Answer.all.each { |a| a.has_fatal_warning?.should be_false }
        Answer.all.each { |a| a.has_warning?.should be_false }
        batch_file.record_count.should == 3
                                   # summary report should exist but not detail report
        batch_file.summary_report_path.should_not be_nil
        File.exist?(batch_file.summary_report_path).should be_true
        batch_file.detail_report_path.should be_nil
      end
    end

    describe "with validation errors" do
      it "file that just has blank rows fails on baby code since baby codes are missing" do
        batch_file = process_batch_file('blank_rows.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded is missing one or more baby codes. Each record must have a baby code. Processing stopped on CSV row 1")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should be_nil
        batch_file.problem_record_count.should be_nil
        batch_file.summary_report_path.should be_nil
        batch_file.detail_report_path.should be_nil
      end

      it "file with missing baby codes should be rejected completely and no reports generated" do
        batch_file = process_batch_file('missing_baby_code.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded is missing one or more baby codes. Each record must have a baby code. Processing stopped on CSV row 2")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should be_nil
        batch_file.problem_record_count.should be_nil
        batch_file.summary_report_path.should be_nil
        batch_file.detail_report_path.should be_nil
      end

      it "file with duplicate baby codes within the file should be rejected completely and no reports generated" do
        batch_file = process_batch_file('duplicate_baby_code.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded contained duplicate baby codes. Each baby code can only be used once. Processing stopped on CSV row 3")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should be_nil
        batch_file.problem_record_count.should be_nil
        batch_file.summary_report_path.should be_nil
        batch_file.detail_report_path.should be_nil
      end

      it "file with duplicate baby codes within the file (with whitespace padding) should be rejected completely and no reports generated" do
        batch_file = process_batch_file('duplicate_baby_code_whitespace.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded contained duplicate baby codes. Each baby code can only be used once. Processing stopped on CSV row 3")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should be_nil
        batch_file.problem_record_count.should be_nil
        batch_file.summary_report_path.should be_nil
        batch_file.detail_report_path.should be_nil
      end

      it "should reject records with missing mandatory fields" do
        batch_file = process_batch_file('missing_mandatory_fields.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not pass validation. Please review the reports for details.")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.summary_report_path.should_not be_nil
        batch_file.detail_report_path.should_not be_nil
      end

      it "should reject records with missing mandatory fields - where the column is missing entirely" do
        batch_file = process_batch_file('missing_mandatory_column.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not pass validation. Please review the reports for details.")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.summary_report_path.should_not be_nil
        batch_file.detail_report_path.should_not be_nil
      end

      it "should reject records with choice answers that are not one of the allowed values for the question" do
        batch_file = process_batch_file('incorrect_choice_answer_value.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not pass validation. Please review the reports for details.")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.summary_report_path.should_not be_nil
        batch_file.detail_report_path.should_not be_nil
      end

      it "should reject records with integer answers that are badly formed" do
        batch_file = process_batch_file('bad_integer.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not pass validation. Please review the reports for details.")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.summary_report_path.should_not be_nil
        batch_file.detail_report_path.should_not be_nil
      end

      it "should reject records with decimal answers that are badly formed" do
        batch_file = process_batch_file('bad_decimal.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not pass validation. Please review the reports for details.")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.summary_report_path.should_not be_nil
        batch_file.detail_report_path.should_not be_nil
      end

      it "should reject records with time answers that are badly formed" do
        batch_file = process_batch_file('bad_time.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not pass validation. Please review the reports for details.")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.summary_report_path.should_not be_nil
        batch_file.detail_report_path.should_not be_nil
      end

      it "should reject records with date answers that are badly formed" do
        batch_file = process_batch_file('bad_date.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not pass validation. Please review the reports for details.")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.summary_report_path.should_not be_nil
        batch_file.detail_report_path.should_not be_nil
      end

      it "should reject records which fail cross-question validations" do
        batch_file = process_batch_file('cross_question_error.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not pass validation. Please review the reports for details.")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.problem_record_count.should == 1
        batch_file.summary_report_path.should_not be_nil
        batch_file.detail_report_path.should_not be_nil

        csv_file = batch_file.detail_report_path
        rows = CSV.read(csv_file)
        rows.size.should eq(2)
        rows[0].should eq(['BabyCode', 'Column Name', 'Type', 'Value', 'Message'])
        rows[1].should eq(['B3', 'Date1', 'Error', '2010-05-29', 'D1 must be >= D2'])
      end

      it "should reject records which fail cross-question validations - date time quad failure" do
        batch_file = process_batch_file('cross_question_error_datetime_comparison.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not pass validation. Please review the reports for details.")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.problem_record_count.should == 1
        batch_file.summary_report_path.should_not be_nil
        batch_file.detail_report_path.should_not be_nil
        File.exist?(batch_file.summary_report_path).should be_true

        csv_file = batch_file.detail_report_path
        rows = CSV.read(csv_file)
        rows.size.should eq(2)
        rows[0].should eq(['BabyCode', 'Column Name', 'Type', 'Value', 'Message'])
        rows[1].should eq(['B3', 'Date1', 'Error', '2010-05-29', 'D1+T1 must be > D2+T2'])
      end

      it "should reject records where the baby code is already in the system" do
        Factory(:response, survey: survey, baby_code: "B2")
        batch_file = process_batch_file('no_errors_or_warnings.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not pass validation. Please review the reports for details.")
        Response.count.should == 1 #the one we created earlier
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.problem_record_count.should == 1
        batch_file.detail_report_path.should_not be_nil
        File.exist?(batch_file.summary_report_path).should be_true

        csv_file = batch_file.detail_report_path
        rows = CSV.read(csv_file)
        rows.size.should eq(2)
        rows[0].should eq(["BabyCode", "Column Name", "Type", "Value", "Message"])
        rows[1].should eq(['B2', 'BabyCode', 'Error', 'B2', 'Baby code B2 has already been used.'])
      end

      it "should reject records where the baby code is already in the system even with whitespace padding" do
        Factory(:response, survey: survey, baby_code: "B2")
        batch_file = process_batch_file('no_errors_or_warnings_whitespace.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not pass validation. Please review the reports for details.")
        Response.count.should == 1 #the one we created earlier
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.problem_record_count.should == 1
        batch_file.detail_report_path.should_not be_nil
        File.exist?(batch_file.summary_report_path).should be_true

        csv_file = batch_file.detail_report_path
        rows = CSV.read(csv_file)
        rows.size.should eq(2)
        rows[0].should eq(["BabyCode", "Column Name", "Type", "Value", "Message"])
        rows[1].should eq(['B2', 'BabyCode', 'Error', 'B2', 'Baby code B2 has already been used.'])
      end

      it "can detect both duplicate baby code and other errors on the same record" do
        Factory(:response, survey: survey, baby_code: "B2")
        batch_file = process_batch_file('missing_mandatory_fields.csv', survey, user)
        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not pass validation. Please review the reports for details.")
        Response.count.should == 1 #the one we created earlier
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.problem_record_count.should == 1
        batch_file.detail_report_path.should_not be_nil
        File.exist?(batch_file.summary_report_path).should be_true

        csv_file = batch_file.detail_report_path
        rows = CSV.read(csv_file)
        rows.size.should eq(3)
        rows[0].should eq(["BabyCode", "Column Name", "Type", "Value", "Message"])
        rows[1].should eq(['B2', 'BabyCode', 'Error', 'B2', 'Baby code B2 has already been used.'])
        rows[2].should eq(['B2', 'TextMandatory', 'Error', '', 'This question is mandatory'])
      end
    end

    describe "with warnings" do
      it "warns on number range issues" do
        batch_file = process_batch_file('number_out_of_range.csv', survey, user)
        batch_file.status.should eq("Needs Review")
        batch_file.message.should eq("The file you uploaded has one or more warnings. Please review the reports for details.")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.problem_record_count.should == 1
        batch_file.summary_report_path.should_not be_nil
        batch_file.detail_report_path.should_not be_nil
      end

      it "accepts number range issues if forced to" do
        # sad path covered earlier
        batch_file = BatchFile.create!(file: Rack::Test::UploadedFile.new('test_data/survey/batch_files/number_out_of_range.csv', 'text/csv'), survey: survey, user: user, hospital: hospital, year_of_registration: 2009)
        batch_file.process
        batch_file.reload

        batch_file.status.should eq("Needs Review")
        batch_file.message.should eq("The file you uploaded has one or more warnings. Please review the reports for details.")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.problem_record_count.should == 1
        batch_file.summary_report_path.should_not be_nil
        batch_file.detail_report_path.should_not be_nil

        batch_file.process(:force)
        batch_file.reload

        batch_file.status.should eq("Processed Successfully")
        batch_file.message.should eq("Your file has been processed successfully.")
        Response.count.should == 3
        Answer.count.should == 20
        batch_file.record_count.should == 3
        batch_file.problem_record_count.should == 1
        batch_file.summary_report_path.should_not be_nil
        batch_file.detail_report_path.should_not be_nil

      end
    end

    describe "with a range of errors and warnings" do
      it "should produce a CSV detail report file with correct error and warning details" do
        batch_file = process_batch_file('a_range_of_problems.csv', survey, user)

        batch_file.status.should eq("Failed")
        batch_file.message.should eq("The file you uploaded did not pass validation. Please review the reports for details.")
        Response.count.should == 0
        Answer.count.should == 0
        batch_file.record_count.should == 3
        batch_file.problem_record_count.should == 3

        csv_file = batch_file.detail_report_path
        rows = CSV.read(csv_file)
        rows.size.should eq(7)
        rows[0].should eq(["BabyCode", "Column Name", "Type", "Value", "Message"])
        rows[1].should eq(['B1', 'Date1', 'Error', '2011-ab-25', 'Answer is invalid (must be a valid date)'])
        rows[2].should eq(['B1', 'Decimal', 'Error', 'a.77', 'Answer is the wrong format (Expected a decimal value)'])
        rows[3].should eq(['B1', 'TextMandatory', 'Error', '', 'This question is mandatory'])
        rows[4].should eq(['B2', 'Integer', 'Warning', '3', 'Answer should be at least 5'])
        rows[5].should eq(['B2', 'Time', 'Error', 'ab:59', 'Answer is invalid (must be a valid time)'])
        rows[6].should eq(['B3', 'Date1', 'Error', '2010-05-29', 'D1 must be >= D2'])

        File.exist?(batch_file.summary_report_path).should be_true
      end

    end
  end

  def process_batch_file(file_name, survey, user, year_of_registration=2009)
    batch_file = BatchFile.create!(file: Rack::Test::UploadedFile.new('test_data/survey/batch_files/' + file_name, 'text/csv'), survey: survey, user: user, hospital: hospital, year_of_registration: year_of_registration)
    batch_file.process
    batch_file.reload
    batch_file
  end
end

