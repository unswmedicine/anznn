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

class Response < ApplicationRecord

  STATUS_UNSUBMITTED = 'Unsubmitted'
  STATUS_SUBMITTED = 'Submitted'

  COMPLETE = 'Complete'
  INCOMPLETE = 'Incomplete'
  COMPLETE_WITH_WARNINGS = 'Complete with warnings'

  BABY_CODE_REGEX = /\A[a-z0-9\-_]+\Z/i

  belongs_to :user
  belongs_to :hospital
  belongs_to :batch_file
  belongs_to :survey

  has_many :answers, dependent: :destroy

  validates_presence_of :baby_code
  validates_presence_of :user
  validates_presence_of :survey_id
  validates_presence_of :hospital_id
  validates_presence_of :year_of_registration
  validates_inclusion_of :submitted_status, in: [STATUS_UNSUBMITTED, STATUS_SUBMITTED]
  validates_uniqueness_of :baby_code, scope: :survey_id
  validates_format_of :baby_code, with: BABY_CODE_REGEX
  validates_length_of :baby_code, maximum: 30

  before_validation :strip_whitespace
  before_validation :clear_dummy_answers
  before_save :compute_validation_status
  before_save :clear_dummy_answers

  scope :for_survey, lambda { |survey| where(survey_id: survey.id) }

  scope :unsubmitted, -> {where(submitted_status: STATUS_UNSUBMITTED)}
  scope :submitted, -> {where(submitted_status: STATUS_SUBMITTED)}

  after_initialize { @dummy_answers = [] }


  # Performance Optimisation: we don't load through the association, instead we do a global lookup by ID
  # to a cached set of surveys that are loaded once in an initializer
  def survey
    SURVEYS[survey_id]
  end

  # as above
  def survey=(survey)
    self.survey_id = survey.id
  end

  def self.for_survey_hospital_and_year_of_registration(survey, hospital_id, year_of_registration)
    results = submitted.for_survey(survey).order(:baby_code)
    results = results.where(hospital_id: hospital_id) unless hospital_id.blank?
    results = results.where(year_of_registration: year_of_registration) unless year_of_registration.blank?
    results.includes([:hospital])
  end

  def self.count_per_survey_and_year_of_registration(survey_id, year)
    Response.where(year_of_registration: year, survey_id: survey_id).count
  end

  def self.delete_by_survey_and_year_of_registration(survey_id, year)
    Response.where(["year_of_registration = ? AND survey_id = ?", year, survey_id]).destroy_all
  end

  def self.existing_years_of_registration
    select("distinct year_of_registration").collect(&:year_of_registration).sort
  end

  def submit!
    if ![COMPLETE, COMPLETE_WITH_WARNINGS].include?(validation_status)
      raise "Can't submit with status #{validation_status}"
    end
    self.submitted_status = STATUS_SUBMITTED
    self.save!
  end

  def submit_warning
    # This method is role-ignorant.
    # Use cancan to check if a response is not submittable before trying to display this
    case validation_status
      when INCOMPLETE
        "This data entry form is incomplete and can't be submitted."
      when COMPLETE_WITH_WARNINGS
        "This data entry form has warnings. Double check them. If you believe them to be correct, contact a supervisor."
      else
        nil
    end
  end

  def prepare_answers_to_section_with_blanks_created(section)
    existing_answers = answers_to_section(section).each_with_object({}) { |answer, hash| hash[answer.question_id] = answer }

    section.questions.each do |question|
      #if there's no answer object already, build an empty one
      if !existing_answers.include?(question.id)
        answer = self.answers.build(question: question)
        answer.response=self
        existing_answers[question.id] = answer
        @dummy_answers << answer
      end
    end
    existing_answers
  end

  def sections_to_answers_with_blanks_created
    survey.sections.reduce({}) do |hsh, section|
      answers = prepare_answers_to_section_with_blanks_created(section).values
      sorted_answers = answers.sort_by { |a| a.question.question_order }
      hsh.merge section => sorted_answers
    end
  end

  def all_answers_with_blanks_created
    sections_to_answers_with_blanks_created.values.flatten
  end

  def section_started?(section)
    !answers_to_section(section).empty?
  end

  def status_of_section(section)
    answers_to_sec = prepare_answers_to_section_with_blanks_created(section).values

    any_mandatory_question_unanswered = answers_to_sec.any? { |a| a.violates_mandatory }
    any_warnings = answers_to_sec.any? { |a| a.warnings.present? }
    any_fatal_warnings = answers_to_sec.any? { |a| a.fatal_warnings.present? }

    if any_fatal_warnings or any_mandatory_question_unanswered
      INCOMPLETE
    elsif any_warnings
      COMPLETE_WITH_WARNINGS
    else
      COMPLETE
    end
  end

  def missing_mandatory_questions
    answers = all_answers_with_blanks_created.select { |a| a.violates_mandatory }
    answers.map(&:question)
  end

  def build_answers_from_hash(hash)
    hash.each do |question_code, answer_text|
      cleaned_text = answer_text.nil? ? "" : answer_text.strip
      question = survey.question_with_code(question_code)
      if question && !cleaned_text.blank?
        answer = answers.build(question: question, response: self)
        answer.answer_value = cleaned_text
      end
    end
  end

  def fatal_warnings?
    all_answers_with_blanks_created.any? do |answer|
      answer.violates_mandatory || answer.fatal_warnings.present?
    end
  end

  def warnings?
    all_answers_with_blanks_created.any? do |answer|
      answer.has_warning?
    end || fatal_warnings?
  end

  #TODO: test me
  def get_answer_to(question_id)
    # this filter through the answer object rather than using find, as we want to use it when we haven't yet saved the objects - DON'T CHANGE THIS BEHAVIOUR
    answers.find { |a| a.question_id == question_id }
  end

  #TODO: test me
  def comparable_answer_or_nil_for_question_with_code(question_code)
    question = survey.question_with_code(question_code)
    raise "No question with code #{question_code}" unless question
    answer = get_answer_to(question.id)
    return nil unless answer
    answer.comparable_answer
  end

  private

  def compute_validation_status
    # don't recompute if we're already submitted, as the process is slow, and once submitted the validations can't change
    return if self.submitted_status == STATUS_SUBMITTED

    section_stati = survey.sections.map { |s| status_of_section(s) }

    if section_stati.include? INCOMPLETE
      self.validation_status = INCOMPLETE
    elsif section_stati.include? COMPLETE_WITH_WARNINGS
      self.validation_status = COMPLETE_WITH_WARNINGS
    else
      self.validation_status = COMPLETE
    end
  end

  def answers_to_section(section)
    answers.select {|a| a.question.section_id == section.id}
  end

  def strip_whitespace
    self.baby_code = self.baby_code.strip unless self.baby_code.nil?
  end

  def clear_dummy_answers
    self.answers.delete(self.answers.select{|elem| @dummy_answers.map(&:object_id).include? elem.object_id})
    @dummy_answers.clear
  end

end
