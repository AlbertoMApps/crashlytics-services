class Service::FogBugz < Service::Base
  title 'FogBugz'

  string :project_url, :placeholder => "https://yourproject.fogbugz.com",
         :label => 'URL to your FogBugz project:'
  string :api_token, :placeholder => 'API Token',
         :label => 'Your FogBugz API Token.'

  page 'API Token', [:project_url, :api_token]

  # Create an issue
  def receive_issue_impact_change(config, payload)
    http.ssl[:verify] = true

    post_body = {
      :sTitle => "#{payload[:title]} [Crashlytics]",
      :sEvent => build_case_event(payload)
    }

    response = http_post fogbugz_url(:cmd => 'new') do |req|
      req.body = post_body
    end

    fogbugz_case, error = parse_response(response, 'response/case')

    if fogbugz_case && !error
      { :fogbugz_case_number => fogbugz_case.attr('ixBug') }
    else
      raise "Could not create FogBugz case: Response: #{error}"
    end
  end

  def receive_verification(config, _)
    http.ssl[:verify] = true

    response = http_get fogbugz_url(:cmd => 'listProjects')

    project, error = parse_response(response, 'response/projects')

    if project && !error
      [true,  'Successfully verified Fogbugz settings']
    else
      if error
        log "Received verification failed: Error code #{error.attr('code')} API key: #{config[:api_key]} Response: #{error}"
      else
        log "Received verification failed: Response: #{error}"
      end
      [false, 'Oops! Please check your API key again.']
    end
  end

  private
  def fogbugz_url(params={})
    query_params = params.map { |k,v| "#{k}=#{v}" }.join('&')

    "#{config[:project_url]}/api.asp?token=#{config[:api_token]}&#{query_params}"
  end

  def build_case_event(payload)
    users_text = if payload[:impacted_devices_count] == 1
      'This issue is affecting at least 1 user who has crashed '
    else
      "This issue is affecting at least #{payload[:impacted_devices_count]} users who have crashed "
    end

    crashes_text = if payload[:crashes_count] == 1
      'at least 1 time.'
    else
      "at least #{payload[:crashes_count]} times."
    end

<<-EOT
Crashlytics detected a new issue.
#{payload[:title]} in #{payload[:method]}

#{users_text}#{crashes_text}

More information: #{payload[:url]}
EOT
  end

  def parse_response(response, subject_selector)
    xml = Nokogiri.XML(response.body)
    error = xml.at('response/error')
    subject = xml.at(subject_selector)
    [subject, error]
  end
end
