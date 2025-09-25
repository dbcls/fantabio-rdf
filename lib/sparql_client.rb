# frozen_string_literal: true
require "net/http"
require "json"
require "fileutils"
require "config_loader"

module SparqlClient
  OUTPUT_DIR = "files"
  QUERY_FILE = File.expand_path("../sparql/ncbigene_symbol.rq", __dir__)

  def self.run
    config = ConfigLoader.load
    endpoint = config["sparql_endpoint"]
    template = File.read(QUERY_FILE)

    FileUtils.mkdir_p(OUTPUT_DIR)

    %w[human mouse].each do |species|
      info = config[species]
      taxid = info["tax"]

      query = template.gsub("{{tax}}", taxid)
      uri = URI(endpoint)
      uri.query = URI.encode_www_form(query: query)

      puts "[#{species}] Querying SPARQL..."
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.get(uri.request_uri, { "Accept" => "application/sparql-results+json" })
      end
      raise "SPARQL query failed: #{res.code}" unless res.is_a?(Net::HTTPSuccess)

      data = JSON.parse(res.body)
      outpath = File.join(OUTPUT_DIR, "#{species}_gene_symbol.tsv")
      File.open(outpath, "w") do |f|
        f.puts "gene\tsymbol"
        data["results"]["bindings"].each do |row|
          f.puts "#{row["gene"]["value"]}\t#{row["symbol"]["value"]}"
        end
      end
      puts "Saved to #{outpath}"
    end
  end
end
