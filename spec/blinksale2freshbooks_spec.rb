require "spec_helper"

RSpec.describe Blinksale2FreshBooks do
  it "has a version number" do
    expect(Blinksale2FreshBooks::VERSION).not_to be nil
  end
  
  it "has a configuration" do
    expect(Blinksale2FreshBooks::configuration).not_to be nil
  end
  
end
