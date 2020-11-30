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

describe StatsReport do

  let(:survey_a) { create(:survey) }
  let(:survey_b) { create(:survey) }
  let(:hospital_a) { create(:hospital) }
  let(:hospital_b) { create(:hospital) }

  describe "Empty" do
    it "should return true if the survey has no responses" do
      create(:response, survey: survey_b, year_of_registration: 2001)
      expect(StatsReport.new(survey_a)).to be_empty
    end
    it "should return true if the survey has no responses" do
      create(:response, survey: survey_a, year_of_registration: 2001)
      expect(StatsReport.new(survey_a)).to_not be_empty
    end
  end

  describe "Getting the possible values for year of registration for a survey" do
    it "should return an array of the years that responses exist for" do
      create(:response, survey: survey_a, year_of_registration: 2001)
      create(:response, survey: survey_a, year_of_registration: 2005)
      create(:response, survey: survey_a, year_of_registration: 2007)
      create(:response, survey: survey_b, year_of_registration: 2002)
      create(:response, survey: survey_b, year_of_registration: 2001)

      expect(StatsReport.new(survey_a).years).to eq([2001, 2005, 2007])
      expect(StatsReport.new(survey_b).years).to eq([2001, 2002])
    end
  end

  describe "Getting the count of responses for a year/status/hospital combination" do
    it "should return the correct count" do
      create(:response, survey: survey_a, year_of_registration: 2001, hospital: hospital_a, submitted_status: Response::STATUS_SUBMITTED)
      create(:response, survey: survey_a, year_of_registration: 2001, hospital: hospital_a, submitted_status: Response::STATUS_SUBMITTED)
      create(:response, survey: survey_a, year_of_registration: 2001, hospital: hospital_a, submitted_status: Response::STATUS_SUBMITTED)
      create(:response, survey: survey_a, year_of_registration: 2001, hospital: hospital_b, submitted_status: Response::STATUS_SUBMITTED)
      create(:response, survey: survey_a, year_of_registration: 2001, hospital: hospital_b, submitted_status: Response::STATUS_SUBMITTED)

      create(:response, survey: survey_a, year_of_registration: 2001, hospital: hospital_a, submitted_status: Response::STATUS_UNSUBMITTED)
      create(:response, survey: survey_a, year_of_registration: 2001, hospital: hospital_b, submitted_status: Response::STATUS_UNSUBMITTED)
      create(:response, survey: survey_a, year_of_registration: 2001, hospital: hospital_b, submitted_status: Response::STATUS_UNSUBMITTED)
      create(:response, survey: survey_a, year_of_registration: 2001, hospital: hospital_b, submitted_status: Response::STATUS_UNSUBMITTED)

      create(:response, survey: survey_a, year_of_registration: 2005, hospital: hospital_a, submitted_status: Response::STATUS_SUBMITTED)
      create(:response, survey: survey_a, year_of_registration: 2005, hospital: hospital_b, submitted_status: Response::STATUS_SUBMITTED)
      create(:response, survey: survey_a, year_of_registration: 2005, hospital: hospital_b, submitted_status: Response::STATUS_SUBMITTED)
      create(:response, survey: survey_a, year_of_registration: 2005, hospital: hospital_b, submitted_status: Response::STATUS_SUBMITTED)

      create(:response, survey: survey_a, year_of_registration: 2007, hospital: hospital_a, submitted_status: Response::STATUS_UNSUBMITTED)
      create(:response, survey: survey_a, year_of_registration: 2007, hospital: hospital_a, submitted_status: Response::STATUS_UNSUBMITTED)

      create(:response, survey: survey_b, year_of_registration: 2002, hospital: hospital_a, submitted_status: Response::STATUS_SUBMITTED)
      create(:response, survey: survey_b, year_of_registration: 2001, hospital: hospital_a, submitted_status: Response::STATUS_SUBMITTED)

      report = StatsReport.new(survey_a)
      expect(report.response_count(2001, Response::STATUS_SUBMITTED, hospital_a.id)).to eq(3)
      expect(report.response_count(2001, Response::STATUS_SUBMITTED, hospital_b.id)).to eq(2)
      expect(report.response_count(2001, Response::STATUS_UNSUBMITTED, hospital_a.id)).to eq(1)
      expect(report.response_count(2001, Response::STATUS_UNSUBMITTED, hospital_b.id)).to eq(3)

      expect(report.response_count(2005, Response::STATUS_SUBMITTED, hospital_a.id)).to eq(1)
      expect(report.response_count(2005, Response::STATUS_SUBMITTED, hospital_b.id)).to eq(3)
      expect(report.response_count(2005, Response::STATUS_UNSUBMITTED, hospital_a.id)).to eq('none')
      expect(report.response_count(2005, Response::STATUS_UNSUBMITTED, hospital_b.id)).to eq('none')

      expect(report.response_count(2007, Response::STATUS_SUBMITTED, hospital_a.id)).to eq('none')
      expect(report.response_count(2007, Response::STATUS_SUBMITTED, hospital_b.id)).to eq('none')
      expect(report.response_count(2007, Response::STATUS_UNSUBMITTED, hospital_a.id)).to eq(2)
      expect(report.response_count(2007, Response::STATUS_UNSUBMITTED, hospital_b.id)).to eq('none')
    end
  end

end