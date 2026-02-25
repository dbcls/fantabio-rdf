# frozen_string_literal: true
require "open-uri"
require "zlib"
require "fileutils"
require "config_loader"

module Downloader
  OUTPUT_DIR = "files"

  def self.run
    config = ConfigLoader.load
    FileUtils.mkdir_p(OUTPUT_DIR)

    config.each do |species, info|
      next unless info.is_a?(Hash) && info["bed"] && info["jsonl"]

      url = info["bed"]
      fname = File.basename(url, ".gz")
      outpath = File.join(OUTPUT_DIR, fname)

      puts "[#{species}] Downloading #{url}..."
      URI.open(url) do |remote|
        Zlib::GzipReader.wrap(remote) do |gz|
          File.open(outpath, "w") { |f| IO.copy_stream(gz, f) }
          com = "cd files; ln -sf #{fname} #{species}_fantabio.bed"
          `#{com}`          
        end
      end
      puts "Saved to #{outpath}"

      url = info["jsonl"]
      fname = File.basename(url, ".gz")
      outpath = File.join(OUTPUT_DIR, fname)

      puts "[#{species}] Downloading #{url}..."
      URI.open(url) do |remote|
        Zlib::GzipReader.wrap(remote) do |gz|
          File.open(outpath, "w") { |f| IO.copy_stream(gz, f) }
          com = "cd files; ln -sf #{fname} #{species}_fantabio.jsonl"
          `#{com}`          
        end
      end
      puts "Saved to #{outpath}"
    end
  end
end
