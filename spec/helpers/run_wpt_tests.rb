require 'open-uri'
require 'net/http'

module Run_WPT_Tests
  @@rest_api_params = nil
  def self.run_script_for_locale
    # puts "Running WPT REST API test for locale: #{$locale}"

    wpt_rest_url = generate_rest_url
    response = initiate_wpt_test(wpt_rest_url)
    summary_csv_content = retrieve_wpt_test_results(response)

    # validate SLAs based on summary CSV received
    Validate_SLAs_From_WPT_Results.for summary_csv_content
  end

  def self.retrieve_wpt_test_results(response)
    # wait for test run to complete
    summary_csv_content = wait_for_wpt_results_to_be_ready(response)
    return summary_csv_content
  end

  def self.wait_for_wpt_results_to_be_ready(response)
    max_time_to_wait_in_sec = 1800 * @@rest_api_params[:runs]
    summary_csv_content = nil

    ten_sec_interval_counter = 0
    number_of_minutes_elapsed = 0
    retry_attempt = 2

    puts "\nWaiting for results"
    puts "Number of runs: #{@@rest_api_params[:runs]}, Max_time_to_wait_in_sec: #{max_time_to_wait_in_sec}"

    summary_csv_content = wait_for_and_retry_once_if_failed(ten_sec_interval_counter, max_time_to_wait_in_sec, number_of_minutes_elapsed, response, retry_attempt)

    puts "Summary csv content: \n#{summary_csv_content.size}"

    return summary_csv_content
  end

  def self.wait_for_and_retry_once_if_failed(ten_sec_interval_counter, max_time_to_wait_in_sec, number_of_minutes_elapsed, response, retry_attempt)
    begin
      timeout(max_time_to_wait_in_sec) {
        while ((summary_csv_content = Net::HTTP.get(URI(response['summaryCSV'] + '?format=csv'))).empty?)
          ten_sec_interval_counter += 1
          ten_sec_interval_counter%6==0 ? ((number_of_minutes_elapsed+=1) && (puts "#{number_of_minutes_elapsed}")) : (putc ".")
          sleep 10
        end
      }
    rescue Timeout::Error => timeout_error
      msg = waiting_for_results_failed_error_msg(max_time_to_wait_in_sec, response, timeout_error)
      raise msg
    rescue => other_error
      if(retry_attempt !=0 )
        retry_attempt -= 1
        msg = "*** Some other error has occurred while waiting for results.\n\n"
        msg += other_error.inspect
        msg += "\n\nRetry waiting for results #{retry_attempt} more time(s)"
        puts msg
        summary_csv_content =wait_for_and_retry_once_if_failed(ten_sec_interval_counter, max_time_to_wait_in_sec, number_of_minutes_elapsed, response, retry_attempt)
      else
        msg = waiting_for_results_failed_error_msg(max_time_to_wait_in_sec, response, other_error)
        raise msg
      end
    end
    summary_csv_content = Net::HTTP.get(URI(response['summaryCSV'] + '?format=csv'))

    return summary_csv_content
  end

  def self.waiting_for_results_failed_error_msg(max_time_to_wait_in_sec, response, some_error)
    msg = "Error getting WPT results in '#{max_time_to_wait_in_sec}' seconds"
    msg += some_error.inspect
    msg += "\n\nAfter the test at #{response['userUrl']} has completed - "
    msg += "\n\tDownload the Summary CSV file from - #{response['summaryCSV']}"
    msg += "\n\tRun the Validate SLAs test to know if SLAs have been breached"
    msg += "\n\t\t'summary_file=<path_to_downloaded_summary_csv_file> bundle exec rspec -t validate_slas'"
    puts msg
    msg
  end

  def self.initiate_wpt_test(wpt_rest_url)
    # run script against WPT using REST APIs
    json_response = JSON.parse(Net::HTTP.get(URI(wpt_rest_url)))
    puts "\nREST API response: #{json_response}"
    Utilities.wait_for(5)
    json_response['data']
  end

  def self.generate_rest_url
    # load script from yml file & randomize
    get_script_and_agent_from_file
    if (!@@rest_api_params[:url].nil?)
      url_or_script_to_run = "url=#{@@rest_api_params[:url]}"
      puts "\nRunning url:\n#{@@rest_api_params[:url]}"
    else
      encoded_script = @@rest_api_params[:script].gsub(/[ ]* /,"\t").gsub(/\|\|/,"\n").gsub(/\t\n\t/,"\n").gsub(/&/,"%26")
      puts "\nRunning script:\n#{@@rest_api_params[:script]}"
      url_or_script_to_run = URI::encode("script='#{encoded_script}'")
    end

    base_url = "#{@@rest_api_params[:wpt_server_address]}/runtest.php"
    location = "location=#{@@rest_api_params[:location]}:#{@@rest_api_params[:browser]}.#{@@rest_api_params[:connectivity]}"
    number_of_runs = "runs=#{@@rest_api_params[:runs]}"
    response_format = "f=#{@@rest_api_params[:response_format]}"
    first_view_only = "fvonly=#{@@rest_api_params[:fvonly]}"
    capture_timeline = "timeline=#{@@rest_api_params[:timeline]}"
    capture_fully_loaded_screenshot = "pngss=#{@@rest_api_params[:pngss]}"
    wpt_server_api_key = "k=#{@@rest_api_params[:key]}"
    test_execution_label = "label=#{@@rest_api_params[:label]}"
    emulate_mobile_browser = "mobile=#{@@rest_api_params[:mobile]}"
    enable_video = "video=#{@@rest_api_params[:video]}"

    options = "#{number_of_runs}&#{response_format}&#{first_view_only}&#{capture_timeline}&#{capture_fully_loaded_screenshot}&#{wpt_server_api_key}&#{location}&#{test_execution_label}&#{emulate_mobile_browser}&#{enable_video}&#{url_or_script_to_run}"

    script_url = base_url + '?' + options
    puts "\nExecuting REST API: #{script_url}"
    script_url
  end

  def self.get_script_and_agent_from_file
    conf = (Utilities.load_from ["wpt_server_configuration"])[:wpt_server]
    loaded_scripts = Utilities.load_from (["scripts"])
    script_to_run = loaded_scripts[:urls][$locale.to_sym][:rest_params]
    if (!script_to_run[:url].nil?)
      Utilities.make_unique (script_to_run[:url])
    else
      Utilities.make_unique (script_to_run[:script])
    end
    Utilities.make_unique (script_to_run[:label])

    @@rest_api_params = conf.deep_merge(script_to_run)
    # puts "\nurl_params: #{@@rest_api_params.inspect}"
  end
end