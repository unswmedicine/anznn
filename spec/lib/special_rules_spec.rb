require 'spec_helper'


describe "Special Rules" do
  pending "shouldn't call 'present' on an answer" do
    survey = Factory.create(:survey)
    section = Factory.create(:section, survey: survey)
    response = Factory.create(:response, survey: survey)
    o2_36wk = Factory.create(:question, section: section, code: 'O2_36wk_', question_type: Question::TYPE_INTEGER)
    gest = Factory.create(:question, section: section, code: SpecialRules::GEST_CODE, question_type: Question::TYPE_INTEGER)
    wght = Factory.create(:question, section: section, code: SpecialRules::WGHT_CODE, question_type: Question::TYPE_INTEGER)

    survey.send(:populate_question_hash)

    cqv = Factory.create(:cross_question_validation, rule: 'special_o2_a', related_question: nil, question: o2_36wk, error_message: 'If O2_36wk_ is -1 and (Gest must be <32 or Wght must be <1500) then (Gest+Gestdays + weeks(DOB and the latest date of (LastO2|CeaseCPAPDate|CeaseHiFloDate))) >36')

    gest_answer = Factory.create(:answer, question: gest, response: @response, answer_value: CrossQuestionValidation::GEST_LT - 1)
    a = Factory.create(:answer, question: o2_36wk, response: @response, answer_value: '-1')
    raise "#{a.response.answers.inspect} #{a.response.answers.count}" # gives "[] 2" ????

    warnings = CrossQuestionValidation.check(a)
    warnings.should be_present
  end

  describe "RULE: special_cool_hours" do
    #hours between |CeaseCoolDate+CeaseCoolTime - StartCoolDate+StartCoolTime| should not be greater than 120 hours
    before(:each) do
      @survey = Factory(:survey)
      @section = Factory(:section, survey: @survey)
      @start_cool_date = Factory(:question, code: 'StartCoolDate', section: @section, question_type: Question::TYPE_DATE)
      @start_cool_time = Factory(:question, code: 'StartCoolTime', section: @section, question_type: Question::TYPE_TIME)
      @cease_cool_date = Factory(:question, code: 'CeaseCoolDate', section: @section, question_type: Question::TYPE_DATE)
      @cease_cool_time = Factory(:question, code: 'CeaseCoolTime', section: @section, question_type: Question::TYPE_TIME)
      @cqv = Factory(:cross_question_validation, rule: 'special_cool_hours', question: @start_cool_date, error_message: 'My message', related_question_id: nil)
      @response = Factory(:response, survey: @survey)
    end

    it 'should raise an error if used on the wrong question' do
      q = Factory(:question, code: 'Blah')
      cqv = Factory.build(:cross_question_validation, rule: 'special_cool_hours', question: q)
      cqv.valid?.should be_false
      cqv.errors[:base].should eq ['special_cool_hours requires question code StartCoolDate but got Blah']
    end

    describe 'should fail when hour difference is > 120' do
      it 'over by 1 minute' do
        cool_hours_test('2013-05-01', '11:59', '2013-05-06', '12:00', 'My message')
      end
      it 'over by a lot' do
        cool_hours_test('2013-05-01', '11:59', '2013-06-04', '12:00', 'My message')
      end
    end

    it 'should pass when hour difference is = 72' do
      cool_hours_test('2013-05-01', '11:59', '2013-05-06', '11:59', nil)
    end

    describe 'should pass when hour difference is < 72' do
      it 'under by 1 minute' do
        cool_hours_test('2013-05-01', '11:59', '2013-05-06', '11:58', nil)
      end
      it 'under by a lot' do
        cool_hours_test('2013-05-01', '11:59', '2013-05-02', '11:59', nil)
      end
    end

    describe 'should pass if all 4 questions not answered' do
      it {cool_hours_test('2013-05-01', nil, '2013-06-04', '12:00', nil)}
      it {cool_hours_test('2013-05-01', '11:59', nil, '12:00', nil)}
      it {cool_hours_test('2013-05-01', '11:59', '2013-06-04', nil, nil)}
    end

    def cool_hours_test(start_date, start_time, cease_date, cease_time, outcome)
      answer = Factory(:answer, question: @start_cool_date, answer_value: start_date, response: @response)
      Factory(:answer, question: @start_cool_time, answer_value: start_time, response: @response) unless start_time.nil?
      Factory(:answer, question: @cease_cool_date, answer_value: cease_date, response: @response) unless cease_date.nil?
      Factory(:answer, question: @cease_cool_time, answer_value: cease_time, response: @response) unless cease_time.nil?
      answer.reload
      @cqv.check(answer).should eq(outcome)
    end

  end

  describe "RULE: special_o2_a" do
    #If O2_36wk_ is -1 and (Gest must be <32 or Wght must be <1500) and (Gest+Gestdays + weeks(DOB and the latest date of (LastO2|CeaseCPAPDate|CeaseHiFloDate))) >36
    before(:each) do
      @survey = Factory(:survey)
      @section = Factory(:section, survey: @survey)
      @o2_36_wk = Factory(:question, code: 'O2_36wk_', section: @section, question_type: Question::TYPE_CHOICE)
      Factory(:question_option, question: @o2_36_wk, option_value: 99)
      Factory(:question_option, question: @o2_36_wk, option_value: 0)
      Factory(:question_option, question: @o2_36_wk, option_value: -1)
      @gest = Factory(:question, code: 'Gest', section: @section, question_type: Question::TYPE_INTEGER)
      @gest_days = Factory(:question, code: 'Gestdays', section: @section, question_type: Question::TYPE_INTEGER)
      @dob = Factory(:question, code: 'DOB', section: @section, question_type: Question::TYPE_DATE)
      @last_o2 = Factory(:question, code: 'LastO2', section: @section, question_type: Question::TYPE_DATE)
      @cease_cpap = Factory(:question, code: 'CeaseCPAPDate', section: @section, question_type: Question::TYPE_DATE)
      @cease_hiflo = Factory(:question, code: 'CeaseHiFloDate', section: @section, question_type: Question::TYPE_DATE)
      @cqv = Factory(:cross_question_validation, rule: 'special_o2_a', question: @o2_36_wk, error_message: 'My message', related_question_id: nil)
      @response = Factory(:response, survey: @survey)
    end

    it 'should raise an error if used on the wrong question' do
      q = Factory(:question, code: 'Blah')
      cqv = Factory.build(:cross_question_validation, rule: 'special_o2_a', question: q)
      cqv.valid?.should be_false
      cqv.errors[:base].should eq ['special_o2_a requires question code O2_36wk_ but got Blah']
    end

    it 'should pass when O2_36wk_ is anything other than -1' do
      [0, 99].each do |answer_val|
        answer = Factory(:answer, question: @o2_36_wk, answer_value: answer_val, response: @response)
        @cqv.check(answer).should be_nil
      end
    end

    describe 'when O2_36wk_ is -1' do
      it 'should pass when not premature' do
        # logic for "Gest must be <32 or Wght must be <1500" is tested separately, so mock that part to simplify testing here
        CrossQuestionValidation.should_receive(:check_gest_wght).and_return(false)
        answer = Factory(:answer, question: @o2_36_wk, answer_value: -1, response: @response)
        @cqv.check(answer).should be_nil
      end

      describe 'When premature' do
        it 'should fail when any of Gest, Gestdays, DOB are not answered' do
          # TODO: clarify that fail is correct here, unclear from description
          # logic for Gest must be <32 or Wght must be <1500 is tested separately, so mock that part to simplify testing here
          CrossQuestionValidation.should_receive(:check_gest_wght).exactly(3).times.and_return(true)
          answer = Factory(:answer, question: @o2_36_wk, answer_value: -1, response: @response)
          Factory(:answer, question: @gest, answer_value: '38', response: @response)
          Factory(:answer, question: @gest_days, answer_value: '5', response: @response)
          Factory(:answer, question: @dob, answer_value: '2013-01-01', response: @response)
          answer.reload
          [@gest, @gest_days, @dob].each do |q|
            answer.response.answers.where(question_id: q.id).destroy_all
            @cqv.check(answer).should eq("My message")
          end
        end

        it 'should fail when none of LastO2, CeaseCPAPDate, CeaseHiFloDate are answered' do
          # logic for Gest must be <32 or Wght must be <1500 is tested separately, so mock that part to simplify testing here
          # TODO: clarify that fail is correct here, unclear from description
          CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
          answer = Factory(:answer, question: @o2_36_wk, answer_value: -1, response: @response)
          Factory(:answer, question: @gest, answer_value: '38', response: @response)
          Factory(:answer, question: @gest_days, answer_value: '5', response: @response)
          Factory(:answer, question: @dob, answer_value: '2013-01-01', response: @response)
          answer.reload
          @cqv.check(answer).should eq("My message")
        end

        # testing and (Gest+Gestdays + weeks(DOB and the latest date of (LastO2|CeaseCPAPDate|CeaseHiFloDate))) >36
        describe 'date calculations' do
          # 36 weeks = 252 days
          it 'should pass when total > 36' do
            CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
            answer = Factory(:answer, question: @o2_36_wk, answer_value: -1, response: @response)
            Factory(:answer, question: @gest, answer_value: '33', response: @response) # 231
            Factory(:answer, question: @gest_days, answer_value: '2', response: @response) # 2
            Factory(:answer, question: @dob, answer_value: '2013-01-01', response: @response)
            Factory(:answer, question: @cease_cpap, answer_value: '2013-01-21', response: @response) # 20 d diff
            answer.reload
            @cqv.check(answer).should be_nil
          end

          it 'should fail when total = 36' do
            CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
            answer = Factory(:answer, question: @o2_36_wk, answer_value: -1, response: @response)
            Factory(:answer, question: @gest, answer_value: '33', response: @response) # 231
            Factory(:answer, question: @gest_days, answer_value: '2', response: @response) # 2
            Factory(:answer, question: @dob, answer_value: '2013-01-01', response: @response)
            Factory(:answer, question: @cease_cpap, answer_value: '2013-01-20', response: @response) # 19 d diff
            answer.reload
            @cqv.check(answer).should eq('My message')
          end

          it 'should fail when total < 36' do
            CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
            answer = Factory(:answer, question: @o2_36_wk, answer_value: -1, response: @response)
            Factory(:answer, question: @gest, answer_value: '33', response: @response) # 231
            Factory(:answer, question: @gest_days, answer_value: '2', response: @response) # 2
            Factory(:answer, question: @dob, answer_value: '2013-01-01', response: @response)
            Factory(:answer, question: @cease_cpap, answer_value: '2013-01-19', response: @response) # 18 d diff
            answer.reload
            @cqv.check(answer).should eq('My message')
          end

          it 'with different question as latest date' do
            CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
            answer = Factory(:answer, question: @o2_36_wk, answer_value: -1, response: @response)
            Factory(:answer, question: @gest, answer_value: '33', response: @response) # 231
            Factory(:answer, question: @gest_days, answer_value: '2', response: @response) # 2
            Factory(:answer, question: @dob, answer_value: '2013-01-01', response: @response)

            Factory(:answer, question: @cease_cpap, answer_value: '2013-01-10', response: @response)
            Factory(:answer, question: @cease_hiflo, answer_value: '2013-01-19', response: @response)
            Factory(:answer, question: @last_o2, answer_value: '2013-01-21', response: @response) # 18 d diff
            answer.reload
            @cqv.check(answer).should be_nil
          end
        end
      end
    end
  end

  describe "RULE: special_hmeo2" do
    # If HmeO2 is -1 and (Gest must be <32 or Wght must be <1500) and HomeDate must be a date and HomeDate must be the same as LastO2
    before(:each) do
      @survey = Factory(:survey)
      @section = Factory(:section, survey: @survey)
      @hme_o2 = Factory(:question, code: 'HmeO2', section: @section, question_type: Question::TYPE_CHOICE)
      Factory(:question_option, question: @hme_o2, option_value: 99)
      Factory(:question_option, question: @hme_o2, option_value: 0)
      Factory(:question_option, question: @hme_o2, option_value: -1)
      @gest = Factory(:question, code: 'Gest', section: @section, question_type: Question::TYPE_INTEGER)
      @gest_days = Factory(:question, code: 'Gestdays', section: @section, question_type: Question::TYPE_INTEGER)
      @home_date = Factory(:question, code: 'HomeDate', section: @section, question_type: Question::TYPE_DATE)
      @last_o2 = Factory(:question, code: 'LastO2', section: @section, question_type: Question::TYPE_DATE)
      @cqv = Factory(:cross_question_validation, rule: 'special_hmeo2', question: @hme_o2, error_message: 'My message', related_question_id: nil)
      @response = Factory(:response, survey: @survey)
    end

    it 'should raise an error if used on the wrong question' do
      q = Factory(:question, code: 'Blah')
      cqv = Factory.build(:cross_question_validation, rule: 'special_hmeo2', question: q)
      cqv.valid?.should be_false
      cqv.errors[:base].should eq ['special_hmeo2 requires question code HmeO2 but got Blah']
    end

    it 'should pass when HmeO2 is anything other than -1' do
      [0, 99].each do |answer_val|
        answer = Factory(:answer, question: @hme_o2, answer_value: answer_val, response: @response)
        @cqv.check(answer).should be_nil
      end
    end

    describe 'when HmeO2 is -1' do
      it 'should pass when not premature' do
        # logic for "Gest must be <32 or Wght must be <1500" is tested separately, so mock that part to simplify testing here
        CrossQuestionValidation.should_receive(:check_gest_wght).and_return(false)
        answer = Factory(:answer, question: @hme_o2, answer_value: -1, response: @response)
        @cqv.check(answer).should be_nil
      end

      describe 'When premature' do
        it 'should fail when HomeDate not answered' do
          # logic for "Gest must be <32 or Wght must be <1500" is tested separately, so mock that part to simplify testing here
          CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
          answer = Factory(:answer, question: @hme_o2, answer_value: -1, response: @response)
          @cqv.check(answer).should eq('My message')
        end

        it 'should fail when HomeDate answered but LastO2 not answered' do
          # logic for "Gest must be <32 or Wght must be <1500" is tested separately, so mock that part to simplify testing here
          CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
          answer = Factory(:answer, question: @hme_o2, answer_value: -1, response: @response)
          Factory(:answer, question: @home_date, answer_value: '2013-01-01', response: @response)
          answer.reload
          @cqv.check(answer).should eq('My message')
        end

        it 'should pass when HomeDate and LastO2 are the same' do
          CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
          answer = Factory(:answer, question: @hme_o2, answer_value: -1, response: @response)
          Factory(:answer, question: @home_date, answer_value: '2013-01-01', response: @response)
          Factory(:answer, question: @last_o2, answer_value: '2013-01-01', response: @response)
          answer.reload
          @cqv.check(answer).should be_nil
        end

        it 'should fail when HomeDate before LastO2' do
          CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
          answer = Factory(:answer, question: @hme_o2, answer_value: -1, response: @response)
          Factory(:answer, question: @home_date, answer_value: '2013-01-01', response: @response)
          Factory(:answer, question: @last_o2, answer_value: '2013-01-02', response: @response)
          answer.reload
          @cqv.check(answer).should eq('My message')
        end

        it 'should fail when HomeDate after LastO2' do
          CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
          answer = Factory(:answer, question: @hme_o2, answer_value: -1, response: @response)
          Factory(:answer, question: @home_date, answer_value: '2013-01-02', response: @response)
          Factory(:answer, question: @last_o2, answer_value: '2013-01-01', response: @response)
          answer.reload
          @cqv.check(answer).should eq('My message')
        end
      end
    end
  end

  describe "RULE: special_o2_a_new" do
    # this rule is separate to special_o2_a so that we can maintain backward compatibility with old surveys
    #If O2_36wk_ is -1 and (Gest must be <32 or Wght must be <1500) then (Gest+Gestdays + weeks(DOB and the latest date of (LastRespSupp|CeaseCPAPDate|CeaseHiFloDate))) >35
    before(:each) do
      @survey = Factory(:survey)
      @section = Factory(:section, survey: @survey)
      @o2_36_wk = Factory(:question, code: 'O2_36wk_', section: @section, question_type: Question::TYPE_CHOICE)
      Factory(:question_option, question: @o2_36_wk, option_value: 99)
      Factory(:question_option, question: @o2_36_wk, option_value: 0)
      Factory(:question_option, question: @o2_36_wk, option_value: -1)
      @gest = Factory(:question, code: 'Gest', section: @section, question_type: Question::TYPE_INTEGER)
      @gest_days = Factory(:question, code: 'Gestdays', section: @section, question_type: Question::TYPE_INTEGER)
      @dob = Factory(:question, code: 'DOB', section: @section, question_type: Question::TYPE_DATE)
      @last_resp_supp = Factory(:question, code: 'LastRespSupp', section: @section, question_type: Question::TYPE_DATE)
      @cease_cpap = Factory(:question, code: 'CeaseCPAPDate', section: @section, question_type: Question::TYPE_DATE)
      @cease_hiflo = Factory(:question, code: 'CeaseHiFloDate', section: @section, question_type: Question::TYPE_DATE)
      @cqv = Factory(:cross_question_validation, rule: 'special_o2_a_new', question: @o2_36_wk, error_message: 'My message', related_question_id: nil)
      @response = Factory(:response, survey: @survey)
    end

    it 'should raise an error if used on the wrong question' do
      q = Factory(:question, code: 'Blah')
      cqv = Factory.build(:cross_question_validation, rule: 'special_o2_a_new', question: q)
      cqv.valid?.should be_false
      cqv.errors[:base].should eq ['special_o2_a_new requires question code O2_36wk_ but got Blah']
    end

    it 'should pass when O2_36wk_ is anything other than -1' do
      [0, 99].each do |answer_val|
        answer = Factory(:answer, question: @o2_36_wk, answer_value: answer_val, response: @response)
        @cqv.check(answer).should be_nil
      end
    end

    describe 'when O2_36wk_ is -1' do
      it 'should pass when not premature' do
        # logic for "Gest must be <32 or Wght must be <1500" is tested separately, so mock that part to simplify testing here
        CrossQuestionValidation.should_receive(:check_gest_wght).and_return(false)
        answer = Factory(:answer, question: @o2_36_wk, answer_value: -1, response: @response)
        @cqv.check(answer).should be_nil
      end

      describe 'When premature' do
        it 'should pass when any of Gest, Gestdays, DOB are not answered' do
          # Gest, Gestdays, DOB are mandatory anyway so will already generate errors, therefore we let this rule pass to avoid excessive messages
          # logic for Gest must be <32 or Wght must be <1500 is tested separately, so mock that part to simplify testing here
          CrossQuestionValidation.should_receive(:check_gest_wght).exactly(3).times.and_return(true)
          answer = Factory(:answer, question: @o2_36_wk, answer_value: -1, response: @response)
          Factory(:answer, question: @gest, answer_value: '38', response: @response)
          Factory(:answer, question: @gest_days, answer_value: '5', response: @response)
          Factory(:answer, question: @dob, answer_value: '2013-01-01', response: @response)
          answer.reload
          [@gest, @gest_days, @dob].each do |q|
            answer.response.answers.where(question_id: q.id).destroy_all
            @cqv.check(answer).should be_nil
          end
        end

        it 'should pass when none of LastRespSupp, CeaseCPAPDate, CeaseHiFloDate are answered' do
          # logic for Gest must be <32 or Wght must be <1500 is tested separately, so mock that part to simplify testing here
          # TODO: clarify that fail is correct here, unclear from description
          CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
          answer = Factory(:answer, question: @o2_36_wk, answer_value: -1, response: @response)
          Factory(:answer, question: @gest, answer_value: '38', response: @response)
          Factory(:answer, question: @gest_days, answer_value: '5', response: @response)
          Factory(:answer, question: @dob, answer_value: '2013-01-01', response: @response)
          answer.reload
          @cqv.check(answer).should be_nil
        end

        # testing and (Gest+Gestdays + weeks(DOB and the latest date of (LastRespSupp|CeaseCPAPDate|CeaseHiFloDate))) >36
        describe 'date calculations' do
          # 35 weeks = 245 days
          it 'should pass when total > 35' do
            CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
            answer = Factory(:answer, question: @o2_36_wk, answer_value: -1, response: @response)
            Factory(:answer, question: @gest, answer_value: '33', response: @response) # 231
            Factory(:answer, question: @gest_days, answer_value: '2', response: @response) # 2
            Factory(:answer, question: @dob, answer_value: '2013-01-01', response: @response)
            Factory(:answer, question: @cease_cpap, answer_value: '2013-01-14', response: @response) # 13 d diff
            answer.reload
            @cqv.check(answer).should be_nil
          end

          it 'should fail when total = 35' do
            CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
            answer = Factory(:answer, question: @o2_36_wk, answer_value: -1, response: @response)
            Factory(:answer, question: @gest, answer_value: '33', response: @response) # 231
            Factory(:answer, question: @gest_days, answer_value: '2', response: @response) # 2
            Factory(:answer, question: @dob, answer_value: '2013-01-01', response: @response)
            Factory(:answer, question: @cease_cpap, answer_value: '2013-01-13', response: @response) # 12 d diff
            answer.reload
            @cqv.check(answer).should eq('My message')
          end

          it 'should fail when total < 35' do
            CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
            answer = Factory(:answer, question: @o2_36_wk, answer_value: -1, response: @response)
            Factory(:answer, question: @gest, answer_value: '33', response: @response) # 231
            Factory(:answer, question: @gest_days, answer_value: '2', response: @response) # 2
            Factory(:answer, question: @dob, answer_value: '2013-01-01', response: @response)
            Factory(:answer, question: @cease_cpap, answer_value: '2013-01-12', response: @response) # 11 d diff
            answer.reload
            @cqv.check(answer).should eq('My message')
          end

          it 'with different question as latest date' do
            CrossQuestionValidation.should_receive(:check_gest_wght).and_return(true)
            answer = Factory(:answer, question: @o2_36_wk, answer_value: -1, response: @response)
            Factory(:answer, question: @gest, answer_value: '33', response: @response) # 231
            Factory(:answer, question: @gest_days, answer_value: '2', response: @response) # 2
            Factory(:answer, question: @dob, answer_value: '2013-01-01', response: @response)

            Factory(:answer, question: @cease_cpap, answer_value: '2013-01-10', response: @response)
            Factory(:answer, question: @cease_hiflo, answer_value: '2013-01-19', response: @response)
            Factory(:answer, question: @last_resp_supp, answer_value: '2013-01-14', response: @response) # 13 d diff
            answer.reload
            @cqv.check(answer).should be_nil
          end
        end
      end
    end
  end

  describe "RULE: special_hmeo2_new" do
    # If HmeO2 is -1 and HomeDate is a date then HomeDate must be the same as LastRespSupp
    before(:each) do
      @survey = Factory(:survey)
      @section = Factory(:section, survey: @survey)
      @hme_o2 = Factory(:question, code: 'HmeO2', section: @section, question_type: Question::TYPE_CHOICE)
      Factory(:question_option, question: @hme_o2, option_value: 99)
      Factory(:question_option, question: @hme_o2, option_value: 0)
      Factory(:question_option, question: @hme_o2, option_value: -1)
      @home_date = Factory(:question, code: 'HomeDate', section: @section, question_type: Question::TYPE_DATE)
      @last_resp_supp = Factory(:question, code: 'LastO2', section: @section, question_type: Question::TYPE_DATE)
      @cqv = Factory(:cross_question_validation, rule: 'special_hmeo2_new', question: @hme_o2, error_message: 'My message', related_question_id: nil)
      @response = Factory(:response, survey: @survey)
    end

    it 'should raise an error if used on the wrong question' do
      q = Factory(:question, code: 'Blah')
      cqv = Factory.build(:cross_question_validation, rule: 'special_hmeo2_new', question: q)
      cqv.valid?.should be_false
      cqv.errors[:base].should eq ['special_hmeo2_new requires question code HmeO2 but got Blah']
    end

    it 'should pass when HmeO2 is anything other than -1' do
      [0, 99].each do |answer_val|
        answer = Factory(:answer, question: @hme_o2, answer_value: answer_val, response: @response)
        @cqv.check(answer).should be_nil
      end
    end

    describe 'when HmeO2 is -1' do
      it 'should pass when HomeDate not answered' do
        answer = Factory(:answer, question: @hme_o2, answer_value: -1, response: @response)
        @cqv.check(answer).should be_nil
      end

      it 'should fail when HomeDate answered but LastRespSupp not answered' do
        answer = Factory(:answer, question: @hme_o2, answer_value: -1, response: @response)
        Factory(:answer, question: @home_date, answer_value: '2013-01-01', response: @response)
        answer.reload
        @cqv.check(answer).should eq('My message')
      end

      it 'should pass when HomeDate and LastRespSupp are the same' do
        answer = Factory(:answer, question: @hme_o2, answer_value: -1, response: @response)
        Factory(:answer, question: @home_date, answer_value: '2013-01-01', response: @response)
        Factory(:answer, question: @last_resp_supp, answer_value: '2013-01-01', response: @response)
        answer.reload
        @cqv.check(answer).should be_nil
      end

      it 'should fail when HomeDate before LastRespSupp' do
        answer = Factory(:answer, question: @hme_o2, answer_value: -1, response: @response)
        Factory(:answer, question: @home_date, answer_value: '2013-01-01', response: @response)
        Factory(:answer, question: @last_resp_supp, answer_value: '2013-01-02', response: @response)
        answer.reload
        @cqv.check(answer).should eq('My message')
      end

      it 'should fail when HomeDate after LastO2' do
        answer = Factory(:answer, question: @hme_o2, answer_value: -1, response: @response)
        Factory(:answer, question: @home_date, answer_value: '2013-01-02', response: @response)
        Factory(:answer, question: @last_resp_supp, answer_value: '2013-01-01', response: @response)
        answer.reload
        @cqv.check(answer).should eq('My message')
      end
    end
  end
end
