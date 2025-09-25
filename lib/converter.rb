# frozen_string_literal: true
require "json"
require "fileutils"
require "config_loader"
require_relative "utils"

module Converter
  INPUT_DIR = "files"
  OUTPUT_DIR = "output"

  def self.run
    config = ConfigLoader.load
    FileUtils.mkdir_p(OUTPUT_DIR)

    inputs = {
      "human" => File.join(INPUT_DIR, "human_fantabio.jsonl"),
      "mouse" => File.join(INPUT_DIR, "mouse_fantabio.jsonl")
    }

    inputs.each do |species, inpath|
      outpath = File.join(OUTPUT_DIR, "#{species}.ttl")
      sym2gene = Utils.load_symbol_to_geneid(File.join(INPUT_DIR, "#{species}_gene_symbol.tsv"))

      File.open(outpath, "w") do |out|
        out.puts Utils.prefixes
        File.foreach(inpath, chomp: true) do |line|
          next if line.strip.empty?
          rec = JSON.parse(line) rescue nil
          next unless rec
          out.puts Utils.record_to_ttl(rec, species, sym2gene)
        end
      end
      puts "Wrote #{outpath}"
    end
  end
end
