require 'rspec'
require "net/http"
require 'nokogiri'
require 'json'
require 'pry'
require 'rspec/expectations'

def require_dependencies
  ['helpers'].each do |folder|
    Dir.glob(File.join('./spec', "#{folder}", "**", "*.rb")) do |file|
      require file
    end
  end
end

def before_check_server(config)
  config.before(:example, :check_server) {
    $test_type = "check_server"
    puts "Before Hook: #{$test_type}"
    urls = Utilities.load_and_sanitize ["base-urls", "#{$env}-urls"]
    $locale = ENV['locale'] ? ENV['locale'].downcase : urls.keys[$time.hour%urls.keys.size]
    $expected_test_results = urls[$locale.to_sym]
  }
end

def before_check_sites(config)
  config.before(:example, :check_sites) {
    $test_type = "check_sites"
    puts "Before Hook: #{$test_type}"
    $expected_test_results = Utilities.load_and_sanitize ["urls"]
  }
end

def before_validate_slas(config)
  config.before(:example, :validate_slas) {
    $test_type = "check_client_perf"
    puts "Before Hook: #{$test_type}"
    urls = Utilities.load_and_sanitize ["base-urls", "#{$env}-urls"]
    $locale = ENV['locale'] ? ENV['locale'].downcase : "sony_uk"
    $expected_test_results = urls[$locale.to_sym]
  }
end

def before_run_wpt(config)
  config.before(:example, :run_wpt) {
    $test_type = "check_client_perf"
    puts "Before Hook: #{$test_type}"
    urls = Utilities.load_and_sanitize ["base-urls", "#{$env}-urls"]
    $locale = ENV['locale'] ? ENV['locale'].downcase : "sony_uk"
    $expected_test_results = urls[$locale.to_sym]
  }
end

def before_each_spec(config)
  config.before(:each) { |s|
    puts "\nRunning spec: '#{s.example_group.metadata[:full_description]}'"
    $random_param = $time.to_i.to_s
    $validation_errors = []
  }
end

def after_each_spec(config)
  config.after(:each) {
    if !$validation_errors.empty?
      msg = "Spec failed. # of validation errors: #{$validation_errors.size}"
      $validation_errors.each do |error|
        msg += "\n\t" + error
      end
      $validation_errors.clear
      raise StandardError.new("Boom! #{msg}")
    end
  }
end

RSpec.configure do |config|
  config.order = "random"
  config.run_all_when_everything_filtered = false
  before_check_server(config)
  before_check_sites(config)
  before_validate_slas(config)
  before_run_wpt(config)
  before_each_spec(config)
  after_each_spec(config)
end

require_dependencies
$env = ENV['env'] ? ENV['env'].downcase : "prod"
$time = Time.now
$validation_errors=[]

puts "Running tests at #{$time} against: #{$env}"