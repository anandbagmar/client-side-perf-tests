module Capture_Data
  def self.validate_data_markers_for(locale)
    locale_urls = $expected_test_results
    validate_data_markers_for_locale(locale, locale_urls)
  end

  def self.monitor_sites_are_available
    $expected_test_results.each_key do |locale|
      validate_data_markers_for_locale(locale, $expected_test_results[locale])
    end
  end

  private

  def self.validate_data_markers_for_page_type(locale, page_type, page_type_data)
    if (page_type_data[:url].nil?)
      puts "\tSkip - No URL specified"
    else
      body, res = get_response_for_url(page_type_data[:url])
      expect(res.code.to_i).to be < 400

      all_expected_content = page_type_data[:expected_data]
      all_expected_content.each_key { |css_locator_for_expected_content|
        expected_content = all_expected_content[css_locator_for_expected_content]
        actual_content = body.at_css(css_locator_for_expected_content).text
        # puts "expected_content: #{expected_content}, actual_content: #{actual_content}"
        msg = "Data Marker not present for: #{locale}:#{page_type}:#{css_locator_for_expected_content}"
        Utilities.verify msg do
          expect(actual_content).to eq(expected_content)
        end
      }
    end
  end

  def self.get_response_for_url(url)
    unique_url = Utilities.make_unique(url)
    uri = URI.parse(unique_url)
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    res = http.request(request)
    body = Nokogiri::XML(res.body)
    puts "\tURL: #{unique_url}, Response code: #{res.code}"
    return body, res
  end

  def self.validate_data_markers_for_locale(locale, locale_urls)
    locale_urls.each_key do |page_type|
      puts "Validate Data Markers for #{locale} - #{page_type}"
      page_type_data = locale_urls[page_type]
      validate_data_markers_for_page_type(locale, page_type, page_type_data)
    end
  end
end