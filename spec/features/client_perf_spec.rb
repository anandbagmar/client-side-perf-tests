require 'spec_helper'

describe 'Validate Client-Side Performance Tests', :validate_slas do
  context "using WPT" do
    it "should validate if SLA has breached" do
      summary_file = ENV['summary_file'].nil? ? "./spec/resources/check_client_perf/sample_summary_files/150402_W3_2_summary.csv" : ENV['summary_file']
      Validate_SLAs_From_WPT_Results.for summary_file
    end
  end
end

describe 'Run Client-Side Performance Tests', :run_wpt do
  context "using WPT-Private instance, in AWS" do
    it 'should run WPT - REST API based tests to validate if SLA has breached' do
      Run_WPT_Tests.run_script_for_locale
    end
  end
end
