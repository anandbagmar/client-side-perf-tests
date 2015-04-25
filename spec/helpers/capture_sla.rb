module Capture_SLA
  @@negate_condition_check = [:overall_score]

  def self.validate_slas_for(locale)
    $expected_test_results.each_key do |page_type|
      puts "Validate SLAs for #{locale} - #{page_type}"
      page_type_data = $expected_test_results[page_type]
      if (page_type_data[:url].nil?)
        puts "\tSkip - No URL specified"
      else
        command_output = get_slas_from_yslow_phantomjs(page_type_data[:url])
        actual_slas = extract_slas(command_output)
        expected_sla = page_type_data[:expected_sla]
        validate_slas_for_page_type(locale, page_type, actual_slas, expected_sla)
      end
    end
  end

  private

  def self.get_slas_from_yslow_phantomjs(url)
    command = "#{Utilities.path_to_phantomJS} ./lib/yslow.min.js -i grade #{Utilities.make_unique(url)}"
    command_output = `#{command}`
  end

  def self.validate_slas_for_page_type(region, page_type, actual_slas, expected_sla)
    expected_sla.each_key { |sla_key|
      msg = "SLA breached for: #{region}:#{page_type}:#{sla_key}"
      if (@@negate_condition_check.include?(sla_key))
        Utilities.verify msg do
          expect(actual_slas[sla_key].to_i).to be >= (expected_sla[sla_key].to_i)
        end
      else
        Utilities.verify msg do
          expect(actual_slas[sla_key].to_i).to be <= (expected_sla[sla_key].to_i)
        end
      end
    }
  end

  def self.extract_slas(command_output)
    actual_slas = {}
    response = JSON.parse(command_output, :symbolize_names => true)
    actual_slas[:url] = URI.decode response[:u]
    actual_slas[:size] = response[:w]
    actual_slas[:overall_score] = response[:o]
    actual_slas[:num_requests] = response[:r]
    actual_slas[:page_load_time] = response[:lt]
    dump(actual_slas)
    actual_slas
  end

  def self.dump(actual_slas)
    puts "\tActual SLAs for : #{actual_slas[:url]}"
    puts "\tPage Size       : #{actual_slas[:size]} bytes"
    puts "\tOverall Score   : #{actual_slas[:overall_score]} bytes"
    puts "\t# of requests   : #{actual_slas[:num_requests]}"
    puts "\tPage load time  : #{actual_slas[:page_load_time]} ms"
  end
end
