require 'spec_helper'

describe 'Monitor-site-is-responding', :check_server do
  context "check SLAs (using phantomJS-yslow)" do
    it "for #{$locale} pages" do
      Capture_SLA.validate_slas_for($locale)
    end
  end
end

describe 'Monitor-site-is-responding', :check_server do
  context "check content (Data Markers) (using Net:HTTP)" do
    it "for #{$locale} pages" do
      Capture_Data.validate_data_markers_for($locale)
    end
  end
end

