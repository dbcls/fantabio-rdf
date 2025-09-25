# frozen_string_literal: true
require "json"

module ConfigLoader
  CONFIG_PATH = File.expand_path("../config.json", __dir__)

  def self.load
    JSON.parse(File.read(CONFIG_PATH))
  end
end
