module NavigationHelpers
  # Maps a name to a path. Used by the
  #
  #   When /^I go to (.+)$/ do |page_name|
  #
  # step definition in web_steps.rb
  #
  def path_to(page_name)
    case page_name

    when /^the home\s?page$/
      '/'

        # User paths
    when /the login page/
      new_user_session_path

    when /the logout page/
      destroy_user_session_path

    when /the user profile page/
      users_profile_path

    when /the request account page/
      new_user_registration_path

    when /the edit my details page/
      edit_user_registration_path

    when /^the user details page for (.*)$/
      admin_user_path(User.where(:email => $1).first)

    when /^the edit role page for (.*)$/
      edit_role_admin_user_path(User.where(:email => $1).first)

    when /^the reset password page$/
      edit_user_password_path

    # Users paths
    when /the access requests page/
      access_requests_admin_users_path

    when /the list users page/
      admin_users_path

    when /the edit first response page$/
      edit_response_path Response.first

    when /the response page for (.*)$/
      response = Response.find_by_baby_code($1)
      edit_response_path response

    when /the response summary page for (.*)$/
      response = Response.find_by_baby_code($1)
      response_path response

    when /the review answers page for (.*)$/
      response = Response.find_by_baby_code($1)
      review_answers_response_path response

    when /the edit section (.*) page$/
      section_order = $1
      section = Section.find_by_section_order!(section_order)
      response = Response.first
      edit_response_path response, section: section

    when /the upload batch file page/
      new_batch_file_path

    when /the configure year of registration range page/
      edit_year_of_registration_configuration_items_path

    when /the list of batch uploads page/
      batch_files_path

    when /the stats page/
      stats_responses_path

    when /the download page/
      prepare_download_responses_path

    when /the download link for the first survey/
      download_responses_path(survey_id: Survey.first.id, hospital_id: "", year_of_registration: "")

    when /the submitted baby codes page/
        submitted_baby_codes_responses_path

    # Add more mappings here.
    # Here is an example that pulls values out of the Regexp:
    #
    #   when /^(.*)'s profile page$/i
    #     user_profile_path(User.find_by_login($1))

    else
      begin
        page_name =~ /^the (.*) page$/
        path_components = $1.split(/\s+/)
        self.send(path_components.push('path').join('_').to_sym)
      rescue NoMethodError, ArgumentError
        raise "Can't find mapping from \"#{page_name}\" to a path.\n" +
          "Now, go and add a mapping in #{__FILE__}"
      end
    end
  end
end

World(NavigationHelpers)
