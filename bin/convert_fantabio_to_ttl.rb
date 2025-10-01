#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "optparse"
require "config_loader"
require "downloader"
require "sparql_client"
require "converter"

subcommand = ARGV.shift

case subcommand
when "dl:fanta"
  Downloader.run
when "dl:tsv"
  SparqlClient.run
when "convert:ttl", "convert"
  Converter.run

when "run:all", "all"
  begin
    puts "== Step 1/3: download:jsonl =="
    Downloader.run

    puts "== Step 2/3: download:tsv =="
    SparqlClient.run

    puts "== Step 3/3: convert:ttl =="
    Converter.run

    puts "== Done =="
  rescue => e
    warn "[run:all] aborted: #{e.class} #{e.message}"
    exit 1
  end

else
  puts <<~USAGE
    Usage:
      bin/convert_fantabio_to_ttl.rb dl:fanta    # Download the fanta.bio files by referencing config.json
      bin/convert_fantabio_to_ttl.rb dl:tsv      # Get geneID-symbol_TSV from RDF-portal
      bin/convert_fantabio_to_ttl.rb convert     # JSONL & TSV to TTL
      bin/convert_fantabio_to_ttl.rb all         # Download & convert
  USAGE
  exit 1
end
