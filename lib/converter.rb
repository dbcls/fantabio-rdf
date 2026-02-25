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
      "human" => File.join(INPUT_DIR, "human_fantabio"),
      "mouse" => File.join(INPUT_DIR, "mouse_fantabio")
    }

    inputs.each do |species, inpath|
      outpath = File.join(OUTPUT_DIR, "#{species}.ttl")
      sym2gene = Utils.load_symbol_to_geneid(File.join(INPUT_DIR, "#{species}_gene_symbol.tsv"))

      File.open(outpath, "w") do |out|
        out.puts Utils.prefixes
        File.foreach(inpath + ".bed", chomp: true) do |line|
          next if line.strip.empty?
          rec = line.split(/\t/)
          next unless rec
          out.puts Utils.bed_to_ttl(rec)
        end
        File.foreach(inpath + ".jsonl", chomp: true) do |line|
          next if line.strip.empty?
          rec = JSON.parse(line) rescue nil
          next unless rec
          out.puts Utils.jsonl_to_ttl(rec, species, sym2gene, config)
        end
      end
      puts "Wrote #{outpath}"
    end
    write_metadata
  end

  def self.write_metadata
    print "Version (e.g. v1.2.0): "
    version = $stdin.gets.chomp
    date = Time.now.strftime("%Y-%m-%d+09:00")
    content = <<~TTL
      @prefix dct: <http://purl.org/dc/terms/> .
      @prefix sio: <http://semanticscience.org/resource/> .
      @prefix pav: <http://purl.org/pav/> .
      @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
      <http://rdf.fanta.bio/>  rdf:type        sio:SIO_000750 ;
                               rdfs:label      "Fanta.bio" ;
                               dct:title       "Fanta.bio RDF" ;
                               pav:version     "#{version}" ;
                               dct:created     "#{date}"^^xsd:date ;
                               dct:description "Fanta.bio RDF converted from CRE peaks annotation JSONL." .
    TTL
    outpath = File.join(OUTPUT_DIR, "metadata.ttl")
    File.write(outpath, content)
    puts "Wrote #{outpath}"
  end
end
