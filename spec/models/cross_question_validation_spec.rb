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

describe CrossQuestionValidation do
  describe "Associations" do
    it { should belong_to :question }
    it { should belong_to :related_question }
  end
  describe "Validations" do
    it { should validate_presence_of :question_id }
    it { should validate_presence_of :rule }
    it { should validate_presence_of :error_message }
    context "should check that comparison CQVs have safe operators" do
      specify { expect(build(:cross_question_validation, rule: 'comparison', operator: '')).to_not be_valid }
      specify { expect(build(:cross_question_validation, rule: 'comparison', operator: '>')).to be_valid }
      specify { expect(build(:cross_question_validation, rule: 'comparison', operator: 'dodgy_operator')).to_not be_valid }
    end
    it "should validate that the rule is one of the allowed rules" do
      CrossQuestionValidation.valid_rules.each do |value|
        should allow_value(value).for(:rule)
      end
      expect(build(:cross_question_validation, rule: 'Blahblah')).to_not be_valid
    end
    it "should validate only one of related question, or related question list populated" do
      # 0 0 F
      # 0 1 T
      # 1 0 T
      # 1 1 F

      expect(build(:cross_question_validation, related_question_id: nil, related_question_ids: nil)).to_not be_valid
      expect(build(:cross_question_validation, related_question_id: nil, related_question_ids: [1])).to be_valid
      expect(build(:cross_question_validation, related_question_id: 1, related_question_ids: nil)).to be_valid
      expect(build(:cross_question_validation, related_question_id: 1, related_question_ids: [1])).to_not be_valid

    end
    it "should validate that a CQV is only applied to question codes that they apply to" do
      bad_q = create(:question, code: 'some_rubbish_question_code')
      SpecialRules::RULE_CODES_REQUIRING_PARTICULAR_QUESTION_CODES.each do |rule_code, required_question_code|
        good_q = create(:question, code: required_question_code)

        expect(build(:cross_question_validation, rule: rule_code, question: bad_q)).to_not be_valid
        expect(build(:cross_question_validation, rule: rule_code, question: good_q)).to be_valid
      end
    end
  end

  describe "helpers" do
    ALL_OPERATORS = %w(* / + - % ** == != > < >= <= <=> === eql? equal? = += -+ *= /+ %= **= & | ^ ~ << >> and or && || ! not ?: .. ...)
    UNSAFE_OPERATORS = ALL_OPERATORS - CrossQuestionValidation::SAFE_OPERATORS
    describe 'safe operators' do

      it "should accept 'safe' operators" do
        CrossQuestionValidation::SAFE_OPERATORS.each do |op|
          expect(CrossQuestionValidation.is_operator_safe?(op)).to eq true
        end
      end
      it "should reject 'unsafe' operators" do
        UNSAFE_OPERATORS.each do |op|
          expect(CrossQuestionValidation.is_operator_safe?(op)).to eq false
        end
      end
    end

    describe 'valid set operators' do

      it "should accept valid operators" do
        CrossQuestionValidation::ALLOWED_SET_OPERATORS.each do |op|
          expect(CrossQuestionValidation.is_set_operator_valid?(op)).to eq true
        end
      end
      it "should reject invalid operators" do
        expect(CrossQuestionValidation.is_set_operator_valid?("invalid_operator")).to eq false
        expect(CrossQuestionValidation.is_set_operator_valid?("something_else")).to eq false

      end
    end

    describe 'set_meets_conditions' do
      it "should pass true statements" do
        expect(CrossQuestionValidation.set_meets_condition?([1, 3, 5, 7], "included", 5)).to eq true
        expect(CrossQuestionValidation.set_meets_condition?([1, 3, 5, 7], "excluded", 4)).to eq true
        expect(CrossQuestionValidation.set_meets_condition?([1, 5], "range", 4)).to eq true
        expect(CrossQuestionValidation.set_meets_condition?([1, 5], "range", 1)).to eq true
        expect(CrossQuestionValidation.set_meets_condition?([1, 5], "range", 5)).to eq true
        expect(CrossQuestionValidation.set_meets_condition?([1, 5], "range", 4.9)).to eq true
        expect(CrossQuestionValidation.set_meets_condition?([1, 5], "range", 1.1)).to eq true
      end

      it "should reject false statements" do
        expect(CrossQuestionValidation.set_meets_condition?([1, 3, 5, 7], "included", 4)).to eq false
        expect(CrossQuestionValidation.set_meets_condition?([1, 3, 5, 7], "excluded", 5)).to eq false
        expect(CrossQuestionValidation.set_meets_condition?([1, 5], "range", 0)).to eq false
        expect(CrossQuestionValidation.set_meets_condition?([1, 5], "range", 6)).to eq false
        expect(CrossQuestionValidation.set_meets_condition?([1, 5], "range", 5.1)).to eq false
      end

      it "should reject statements with invalid operators" do
        expect(CrossQuestionValidation.set_meets_condition?([1, 3, 5], "swirly", 0)).to eq false
        expect(CrossQuestionValidation.set_meets_condition?([1, 3, 5], "includified", 0)).to eq false
      end
    end

    describe 'const_meets_conditions' do
      it "should pass true statements" do
        expect(CrossQuestionValidation.const_meets_condition?(0, "==", 0)).to eq true
        expect(CrossQuestionValidation.const_meets_condition?(5, "!=", 3)).to eq true
        expect(CrossQuestionValidation.const_meets_condition?(5, ">=", 3)).to eq true
      end

      it "should reject false statements" do
        expect(CrossQuestionValidation.const_meets_condition?(0, "<", 0)).to eq false
        expect(CrossQuestionValidation.const_meets_condition?(5, "==", 3)).to eq false
        expect(CrossQuestionValidation.const_meets_condition?(5, "<=", 3)).to eq false
      end

      it "should reject statements with unsafe operators" do
        expect(CrossQuestionValidation.const_meets_condition?(0, UNSAFE_OPERATORS.first, 0)).to eq false
        expect(CrossQuestionValidation.const_meets_condition?(0, UNSAFE_OPERATORS.last, 0)).to eq false
      end
    end
  end


  describe "check" do
    before :each do
      @survey = create :survey
      @section = create :section, survey: @survey
    end

    def do_cqv_check (first, val)
      error_messages = CrossQuestionValidation.check first
      expect(error_messages).to eq val
    end

    def standard_cqv_test(val_first, val_second, error)
      first = create :answer, response: @response, question: @q1, answer_value: val_first
      second = create :answer, response: @response, question: @q2, answer_value: val_second

      @response.reload

      do_cqv_check(first, error)
    end

    describe "implications" do
      before :each do
        @response = create :response, survey: @survey
      end
      describe 'date implies constant' do
        before :each do
          @error_message = 'q2 was date, q1 was not expected constant (-1)'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Date'
          create :cqv_present_implies_constant, question: @q1, related_question: @q2, error_message: @error_message, operator: '==', constant: -1
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("doesn't reject the LHS when RHS not a date") { standard_cqv_test({}, "5", []) }
        it("rejects when RHS is date and LHS is not expected constant") { standard_cqv_test(5, Date.new(2012, 2, 3), [@error_message]) }
        it("accepts when RHS is date and LHS is expected constant") { standard_cqv_test(-1, Date.new(2012, 2, 1), []) }
      end

      describe 'constant implies constant' do
        before :each do
          @error_message = 'q2 was != 0, q1 was not > 0'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Integer'
          create :cqv_const_implies_const, question: @q1, related_question: @q2, error_message: @error_message
          #conditional_operator "!="
          #conditional_constant 0
          #operator ">"
          #constant 0
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("doesn't reject the LHS when RHS not expected constant") { standard_cqv_test(-1, 0, []) }
        it("rejects when RHS is specified constant and LHS is not expected constant") { standard_cqv_test(-1, 1, [@error_message]) }
        it("accepts when RHS is specified constant and LHS is expected constant") { standard_cqv_test(1, 1, []) }
      end

      describe 'constant implies set' do
        before :each do
          @error_message = 'q2 was != 0, q1 was not in specified set [1,3,5,7]'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Integer'
          create :cqv_const_implies_set, question: @q1, related_question: @q2, error_message: @error_message
          #conditional_operator "!="
          #conditional_constant 0
          #set_operator "included"
          #set [1,3,5,7]
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("doesn't reject the LHS when RHS not expected constant") { standard_cqv_test(-1, 0, []) }
        it("rejects when RHS is specified const and LHS is not in expected set") { standard_cqv_test(0, 1, [@error_message]) }
        it("accepts when RHS is specified const and LHS is in expected set") { standard_cqv_test(1, 1, []) }
      end

      describe 'set implies set' do
        before :each do
          @error_message = 'q2  was in [2,4,6,8], q1 was not in specified set [1,3,5,7]'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Integer'
          create :cqv_set_implies_set, question: @q1, related_question: @q2, error_message: @error_message
          #conditional_set_operator "included"
          #conditional_set [2,4,6,8]
          #set_operator "included"
          #set [1,3,5,7]
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("doesn't reject the LHS when RHS not in expected set") { standard_cqv_test(-1, 0, []) }
        it("rejects when RHS is in specified set and LHS is in expected set") { standard_cqv_test(0, 2, [@error_message]) }
        it("accepts when RHS is in specified set and LHS is in expected set") { standard_cqv_test(1, 2, []) }
      end

      describe 'present implies present' do
        before :each do
          @error_message = 'q2 must be answered if q1 is'
          @q1 = create :question, section: @section, question_type: 'Date'
          @q2 = create :question, section: @section, question_type: 'Time'
          create :cqv_present_implies_present, question: @q1, related_question: @q2, error_message: @error_message
        end
        it("is not run if the question has a badly formed answer") { standard_cqv_test("2011-12-", "11:53", []) }
        it("passes if both are answered") { standard_cqv_test("2011-12-12", "11:53", []) }
        it "fails if the question is answered and the related question is not" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "2011-12-12"
          do_cqv_check(a1, [@error_message])
        end
        it("fails if the question is answered and the related question has an invalid answer") { standard_cqv_test("2011-12-12", "11:", [@error_message]) }
      end

      describe 'const implies present' do
        before :each do
          @error_message = 'q2 must be answered if q1 is'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Date'
          create :cqv_const_implies_present, question: @q1, related_question: @q2, error_message: @error_message, operator: '==', constant: -1
        end
        it("is not run if the question has a badly formed answer") { standard_cqv_test("ab", "2011-12-12", []) }
        it("passes if both are answered and answer to question == constant") { standard_cqv_test("-1", "2011-12-12", []) }
        it("passes if both are answered and answer to question != constant") { standard_cqv_test("99", "2011-12-12", []) }
        it "fails if related question not answered and answer to question == constant" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "-1"
          do_cqv_check(a1, [@error_message])
        end
        it "passes if related question not answered and answer to question != constant" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "00"
          do_cqv_check(a1, [])
        end
        it("fails if related question has an invalid answer and answer to question == constant") { standard_cqv_test("-1", "2011-12-", [@error_message]) }
      end

      describe 'set implies present' do
        before :each do
          @error_message = 'q2 must be answered if q1 is in [2..7]'
          @q1 = create :question, section: @section, question_type: 'Choice'
          @q2 = create :question, section: @section, question_type: 'Date'
          create :cqv_set_implies_present, question: @q1, related_question: @q2, error_message: @error_message, set_operator: 'range', set: [2, 7]
        end
        it("is not run if the question has a badly formed answer") { standard_cqv_test("ab", "2011-12-12", []) }
        it("passes if both are answered and answer to question is at start of set") { standard_cqv_test("2", "2011-12-12", []) }
        it("passes if both are answered and answer to question is in middle of set") { standard_cqv_test("5", "2011-12-12", []) }
        it("passes if both are answered and answer to question is at end of set") { standard_cqv_test("7", "2011-12-12", []) }
        it "fails if related question not answered and answer to question is at start of set" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "2"
          do_cqv_check(a1, [@error_message])
        end
        it "fails if related question not answered and answer to question is in middle of set" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "5"
          do_cqv_check(a1, [@error_message])
        end
        it "fails if related question not answered and answer to question is at end of set" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "7"
          do_cqv_check(a1, [@error_message])
        end
        it "passes if related question not answered and answer to question is outside range" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "8"
          do_cqv_check(a1, [])
        end
        it("fails if related question has an invalid answer and answer to question in range") { standard_cqv_test("3", "2011-12-", [@error_message]) }
      end

      describe 'const implies one of const' do
        before :each do
          @error_message = 'q2 or q3 must be -1 if q1 is 99'
          @q1 = create :question, section: @section, question_type: 'Choice'
          @q2 = create :question, section: @section, question_type: 'Integer'
          @q3 = create :question, section: @section, question_type: 'Choice'
          @cqv1 = create :cqv_const_implies_one_of_const, question: @q1, related_question: nil, related_question_ids: [@q2.id, @q3.id], error_message: @error_message, operator: '==', constant: 99, conditional_operator: '==', conditional_constant: -1
        end
        it("handles nils") do
          v1 = 99
          v2 = nil
          v3 = nil

          first = create :answer, response: @response, question: @q1, answer_value: v1
          second = create :answer, response: @response, question: @q2, answer_value: v2
          third = create :answer, response: @response, question: @q3, answer_value: v3

          err = @cqv1.check first
          expect(err).to eq @error_message
        end
      end
    end

    describe "Blank Unless " do
      before :each do
        @response = create :response, survey: @survey
      end

      describe 'blank if constant (q must be blank if related q == constant)' do
        # e.g. If Died_ is 0, DiedDate must be blank (rule is on DiedDate)
        before :each do
          @error_message = 'if q2 == -1, q1 must be blank'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Integer'
          create :cqv_blank_if_const, question: @q1, related_question: @q2, error_message: @error_message, conditional_operator: '==', conditional_constant: -1
        end
        it "passes if q2 not answered but q1 is" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "7"
        end
        it("passes if q2 not answered and q1 not answered") {} # rule won't be run
        it("passes if q2 is not -1 and q1 is blank") {} # rule won't be run }
        it("passes if q2 is not -1 and q1 is not blank") { standard_cqv_test(123, 0, []) }
        it("passes when q2 is -1 and q1 is blank") {} # rule won't be run }
        it("fails when q2 is -1 and q1 is not blank") { standard_cqv_test(123, -1, [@error_message]) }
      end
    end

    describe "Present Unless " do
      before :each do
        @response = create :response, survey: @survey
      end

      describe 'present if constant (q must be present if related q == constant)' do
        # e.g. If Died_ is 0, DiedDate must be blank (rule is on DiedDate)
        before :each do
          @error_message = 'if q2 == -1, q1 must be blank'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Integer'
          create :cqv_present_if_const, question: @q1, related_question: @q2, error_message: @error_message, conditional_operator: '==', conditional_constant: -1
        end
        it "passes if q2 not answered but q1 is" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "7"
          do_cqv_check(a1, [])
        end
        it("passes if q2 not answered and q1 answered") {} # rule won't be run
        it("passes if q2 is not -1 and q1 is blank") { standard_cqv_test({}, 0, []) }
        it("passes if q2 is not -1 and q1 is not blank") {} # rule won't be run
        it("passes when q2 is -1 and q1 is not blank") {} # rule won't be run
        it("fails when q2 is -1 and q1 is blank") { standard_cqv_test({}, -1, [@error_message]) }
      end
    end

    describe "comparisons (using dates to represent a complex type that supports <,>,== etc)" do
      before :each do
        @q1 = create :question, section: @section, question_type: 'Date'
        @q2 = create :question, section: @section, question_type: 'Date'
        @response = create :response, survey: @survey
        @response.reload
        expect(@response.answers.count).to eq 0
      end
      describe "date_lte" do
        before :each do
          @error_message = 'not lte'
          create :cross_question_validation, rule: 'comparison', operator: '<=', question: @q1, related_question: @q2, error_message: @error_message
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("rejects gt") { standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), [@error_message]) }
        it("accepts lt") { standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 2), []) }
        it("accepts eq") { standard_cqv_test(Date.new(2012, 2, 2), Date.new(2012, 2, 2), []) }
      end
      describe "date_gte" do
        before :each do
          @error_message = 'not gte'
          create :cross_question_validation, rule: 'comparison', operator: '>=', question: @q1, related_question: @q2, error_message: @error_message
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("accepts gt") { standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), []) }
        it("rejects lt") { standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 2), [@error_message]) }
        it("accepts eq") { standard_cqv_test(Date.new(2012, 2, 2), Date.new(2012, 2, 2), []) }
      end
      describe "date_gt" do
        before :each do
          @error_message = 'not gt'
          create :cross_question_validation, rule: 'comparison', operator: '>', question: @q1, related_question: @q2, error_message: @error_message
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("accepts gt") { standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), []) }
        it("rejects lt") { standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 2), [@error_message]) }
        it("rejects eq") { standard_cqv_test(Date.new(2012, 2, 2), Date.new(2012, 2, 2), [@error_message]) }
      end
      describe "date_lt" do
        before :each do
          @error_message = 'not lt'
          create :cross_question_validation, rule: 'comparison', operator: '<', question: @q1, related_question: @q2, error_message: @error_message
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("rejects gt") { standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), [@error_message]) }
        it("accepts lt") { standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 2), []) }
        it("rejects eq") { standard_cqv_test(Date.new(2012, 2, 2), Date.new(2012, 2, 2), [@error_message]) }
      end
      describe "date_eq" do
        before :each do
          @error_message = 'not eq'
          create :cross_question_validation, rule: 'comparison', operator: '==', question: @q1, related_question: @q2, error_message: @error_message
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("rejects gt") { standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), [@error_message]) }
        it("rejects lt") { standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 2), [@error_message]) }
        it("accepts eq") { standard_cqv_test(Date.new(2012, 2, 2), Date.new(2012, 2, 2), []) }
      end
      describe "date_ne" do
        before :each do
          @error_message = 'are eq'
          create :cross_question_validation, rule: 'comparison', operator: '!=', question: @q1, related_question: @q2, error_message: @error_message
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("accepts gt") { standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), []) }
        it("accepts lt") { standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 2), []) }
        it("rejects eq") { standard_cqv_test(Date.new(2012, 2, 2), Date.new(2012, 2, 2), [@error_message]) }
      end
      describe "comparisons with offsets function normally" do
        #This isn't much to test here: We're utilising the other class' ability to use +/-, so as long
        # As it works for one case involving a 'complex' type, that's good enough.
        before :each do
          @error_message = 'not eq'
        end
        it "accepts X eq Y (offset +1) when Y = X-1" do
          create :cross_question_validation, rule: 'comparison', operator: '==', question: @q1, related_question: @q2, error_message: @error_message, constant: 1
          standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), [])
        end
        it "rejects X eq Y (offset +1) when Y = X" do
          create :cross_question_validation, rule: 'comparison', operator: '==', question: @q1, related_question: @q2, error_message: @error_message, constant: 1
          standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 1), [@error_message])
        end
        it "accepts X eq Y (offset -1) when Y = X+1" do
          create :cross_question_validation, rule: 'comparison', operator: '==', question: @q1, related_question: @q2, error_message: @error_message, constant: -1
          standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 4), [])
        end
        it "rejects X eq Y (offset -1) when Y = X" do
          create :cross_question_validation, rule: 'comparison', operator: '==', question: @q1, related_question: @q2, error_message: @error_message, constant: -1
          standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 1), [@error_message])
        end
      end
    end
  end

  describe 'check if premature' do
    before(:each) do
      @gest_q = create(:question, code: 'Gest', question_type: Question::TYPE_INTEGER)
      @wght_q = create(:question, code: 'Wght', section: @gest_q.section, question_type: Question::TYPE_INTEGER)
    end

    it 'should return false if neither gest nor gest wgt answered' do
      check_gest_wght(nil, nil, nil)       # it returns nil for false in this case

    end
    it 'should return true if gest < 32 OR wght < 1500' do
      check_gest_wght(31, nil, true)
      check_gest_wght(31, 1499, true)
      check_gest_wght(31, 1500, true)
      check_gest_wght(31, 1501, true)

      check_gest_wght(32, nil, nil)# it returns nil for false in this case
      check_gest_wght(32, 1499, true)
      check_gest_wght(32, 1500, false)
      check_gest_wght(32, 1501, false)

      check_gest_wght(33, nil, nil)# it returns nil for false in this case
      check_gest_wght(33, 1499, true)
      check_gest_wght(33, 1500, false)
      check_gest_wght(33, 1501, false)
    end

    def check_gest_wght(gest, wght, expected_result)
      response = create(:response, survey: @gest_q.section.survey)
      create(:answer, question: @gest_q, answer_value: gest, response: response) unless gest.nil?
      create(:answer, question: @wght_q, answer_value: wght, response: response) unless wght.nil?
      any_answer = create(:answer, response: response)
      any_answer.reload
      expect(CrossQuestionValidation.check_gest_wght(any_answer)).to eq(expected_result)
    end
  end
end
