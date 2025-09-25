# fantabio-rdf
Fanta.bio RDF

## Convert to ttl

Excerpt from the created RDF
```
$ bin/convert_fantabio_to_ttl.rb download:jsonl    # download fanta.bio JSONL
$ bin/convert_fantabio_to_ttl.rb download:tsv      # Get geneID-symbol_TSV
$ bin/convert_fantabio_to_ttl.rb convert:ttl       # JSONL + TSV to TTL
```