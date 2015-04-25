require 'rspec/expectations'
require 'yaml'
require 'csv'
require 'rbconfig'

include RbConfig
include RSpec::Matchers

module Utilities
  def self.make_unique(url)
    url.gsub!(/<replace>/, $random_param)
    url
  end

  def self.load_and_sanitize list
    urls = load_from(list)
    urls = sanitize_loaded_data(urls[:urls])
    # puts "Loaded (sanitized) urls: \n#{urls.inspect}"
    urls
  end

  def self.load_from(list)
    merged_urls = {}
    list.each { |item|
      # puts "Loading file: spec/resources/#{$test_type}/#{item}.yml"
      item_urls = YAML.load(File.open("spec/resources/#{$test_type}/#{item}.yml"))
      merged_urls = merged_urls.deep_merge(item_urls)
    }
    urls = symbolize_keys_in_hash merged_urls
    # puts "Loaded urls: \n#{urls.inspect}"
    urls
  end

  def self.verify message, &block
    begin
      yield
    rescue RSpec::Expectations::ExpectationNotMetError => verification_error
      message = "Verification_error: #{message}\n\t\t#{verification_error.message}"
      # puts message
      $validation_errors << message
    end
  end

  def self.path_to_phantomJS
    path = nil
    case CONFIG['host_os']
      # when /mswin|windows/i
      #   # Windows
      when /linux|arch/i
        # Linux
        path = '/usr/bin/phantomjs'
      when /darwin/i
        #MAC OS X
        path = '/usr/local/bin/phantomjs'
      else
        # whatever
        raise "OS #{CONFIG['host_os']} Not supported to run Monitoring tests"
    end
    # puts "phantomJS path: #{path}"
    path
  end

  def self.get_specific_metrics_for_each_url_in_locale_from_wpt_results_ file
    extracted_results = get_wpt_results_from_summary_ file
    extracted_results_based_on_page_type = extract_all_result_metrics_for_each_page_type(extracted_results)
    get_specific_metrics_from (extracted_results_based_on_page_type)
  end

  def self.get_specific_metrics_from (extracted_results_based_on_page_type)
    specific_metrics = {}
    expected_metric_names = get_expected_metrics_from_expected_data
    extracted_results_based_on_page_type.each { |page_type, results|
      specific_metrics_for_page_type = {}
      expected_metrics_for_page_type = expected_metric_names[page_type]
      results.each {|result|
        expected_metrics_for_page_type.each {|metric|
          specific_metrics_for_page_type[metric] ||= []
          specific_metrics_for_page_type[metric] << result[metric]
        }
      }
      specific_metrics[page_type] = specific_metrics_for_page_type if !specific_metrics_for_page_type.empty?
    }
    specific_metrics
  end

  def self.get_expected_metrics_from_expected_data
    expected_metric_names = {}
    $expected_test_results.each_key { |expected_page_type|
      column_names = $expected_test_results[expected_page_type][:expected_sla].keys
      if (column_names.find_index(:url).nil?)
        column_names << :url
      end
      expected_metric_names[expected_page_type] = column_names
    }
    expected_metric_names
  end

  def self.extract_all_result_metrics_for_each_page_type(extracted_results)
    summary_results_for_all_urls ||= {}
    $expected_test_results.each_key { |expected_page_type|
      summary_results_per_url = []
      extracted_results.map { |each_result|
        if ($expected_test_results[expected_page_type][:url]).nil?
          puts "NO URL for #{expected_page_type}. Skipping this expected data."
          break
        elsif !(each_result[:url].index($expected_test_results[expected_page_type][:url]).nil?)
          # puts "Match found:\n\tActual: #{each_result[:url]}\n\tExpected:#{$expected_test_results[expected_page_type][:url]}"
          summary_results_per_url << each_result
        else
          # puts "Match NOT found:\n\tActual: #{each_result[:url]}\n\tExpected:#{$expected_test_results[expected_page_type][:url]}"
        end
      }
      if !($expected_test_results[expected_page_type][:url]).nil?
        summary_results_for_all_urls[expected_page_type.to_sym] = summary_results_per_url
      end
    }
    summary_results_for_all_urls
  end

  def self.get_wpt_results_from_summary_ file
    summary_results ||= []
    csv = extract_results_from_csv file
    csv.to_a.map { |each_row|
      summary_results << each_row.to_hash
    }
    puts "\nActual results"
    puts "\n# of summary results loaded = #{summary_results.length}"
    summary_results
  end

  def self.extract_results_from_csv(file)
    if (File.exist?(file))
      puts "Extracting results from file: #{file}"
      csv_content = File.open(file).read
    else
      csv_content = file
    end
    # puts "csv_content: \n#{csv_content}"
    csv=CSV.new(csv_content, :headers => true, :header_converters => :symbol, :converters => [:all])
  end

  def self.symbolize_keys_in_hash hash
    Hash[hash.map{ |k, v|
           if (v.class == Hash)
             v = symbolize_keys_in_hash v
           end
           [k.to_sym, v]
         }]
  end

  def self.sanitize_loaded_data (urls)
    urls.each { |locale_name,locale_data|
      locale_data.each { |page_type, page_data|
        locale_data.delete(page_type) if(page_data[:url].nil?)
      }
    }
    urls.delete_if {|locale_name, locale_data|
      locale_data.empty?
    }
    urls
  end

  def self.wait_for duration
    sleep duration
  end
end