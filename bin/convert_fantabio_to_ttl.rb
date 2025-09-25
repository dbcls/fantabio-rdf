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
when "download:jsonl"
  Downloader.run
when "download:tsv"
  SparqlClient.run
when "convert:ttl"
  Converter.run
else
  puts <<~USAGE
    Usage:
      bin/convert_fantabio_to_ttl.rb download:jsonl    # config.json の download URL から JSONL を取得
      bin/convert_fantabio_to_ttl.rb download:tsv      # SPARQL クエリを実行して TSV を取得
      bin/convert_fantabio_to_ttl.rb convert:ttl       # JSONL + TSV を TTL に変換
  USAGE
  exit 1
end
