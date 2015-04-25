require 'descriptive_statistics'

module Validate_SLAs_From_WPT_Results
  @@skip_percentile_check = [:url]
  @@grading_check = [:dom_content_ready_end]

  def self.for (file)
    raise "Summary file (or content) not provided" if(file.nil?)

    actual_results = Utilities.get_specific_metrics_for_each_url_in_locale_from_wpt_results_ file
    validate_slas actual_results
  end

  private

  def self.validate_slas actual_results
    expected_slas = $expected_test_results
    puts "\nExpected results for all page types: \n#{$expected_test_results}"
    percentile_of_actual_results = get_percentile_results_for (actual_results)
    expected_slas.each_key { |page_type|
      puts "\nValidating SLA for: #{$env}:#{$locale}:#{page_type}"
      Utilities.verify "No results for page type: #{$env}:#{$locale}:#{page_type}" do
        expect(percentile_of_actual_results[page_type]).not_to be_nil
      end
      if !(percentile_of_actual_results[page_type].nil?)
        validate_slas_for_each_page_type(page_type, expected_slas[page_type], percentile_of_actual_results[page_type])
      end
    }
  end

  def self.validate_slas_for_each_page_type(page_type, expected_slas_for_page_type, percentile_of_actual_results_for_page_type)
    expected_slas_for_page_type[:expected_sla].each { |metric, expected_value|
      puts "\tMetric: #{metric}"
      msg = "SLA breached for #{$env}:#{$locale}:#{page_type} => #{metric}"
      if (@@grading_check.include?(metric))
        msg = validate_slas_based_on_grading(expected_value, metric, msg, page_type, percentile_of_actual_results_for_page_type)
      else
        validate_slas_based_on_percentile(expected_value, metric, msg, percentile_of_actual_results_for_page_type)
      end
    }
  end

  def self.validate_slas_based_on_percentile(expected_value, metric, msg, percentile_of_actual_results_for_page_type)
    exp = expected_value.to_f
    puts "\t\texpect(#{percentile_of_actual_results_for_page_type[metric].round}).to be_between((#{(exp/10).round}, #{expected_value.round})"
    Utilities.verify msg do
      expect(percentile_of_actual_results_for_page_type[metric].round).to be_between((exp/10).round, expected_value.round)
    end
  end

  def self.validate_slas_based_on_grading(expected_value, metric, msg, page_type, percentile_of_actual_results_for_page_type)
    red = expected_value[:red].round
    green = expected_value[:green].round
    if (percentile_of_actual_results_for_page_type[metric] <= green)
      msg += "\n\t\t *** GREEN *** SLA for #{$env}:#{$locale}:#{page_type} => #{metric}"
      puts msg
    elsif (percentile_of_actual_results_for_page_type[metric] <= red)
      msg += "\n\t\t *** AMBER *** SLA for #{$env}:#{$locale}:#{page_type} => #{metric}"
      puts msg
    else
      msg += "\n\t\t *** RED *** SLA for #{$env}:#{$locale}:#{page_type} => #{metric}"
      puts msg
    end
    puts "\t\texpect(#{(percentile_of_actual_results_for_page_type[metric]).round}).to be_between(#{green/2.round}, #{red.round})"
    Utilities.verify msg do
      expect((percentile_of_actual_results_for_page_type[metric]).round).to be_between(green/2.round, red.round)
    end
    msg
  end

  def self.get_percentile_results_for (actual_results, percentile = 95)
    percentile_results_for_all_page_types = {}
    count = 0

    actual_results.each {|page_type, results|
      percentile_results = {}
      count += results[:url].length
      puts "\tNumber of results for #{page_type}: #{results[:url].length}"
      results.each { |metric, values|
        if !(@@skip_percentile_check.include?(metric))
          percentile_results[metric] = values.percentile(percentile).round(1)
        end
      }
      percentile_results_for_all_page_types[page_type] = percentile_results
    }
    puts "\nTotal # of relevant results in summary file: #{count}"
    puts "\n#{percentile} percentile results for all page types: \n#{percentile_results_for_all_page_types}"
    percentile_results_for_all_page_types
  end
end