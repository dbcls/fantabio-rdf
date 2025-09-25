# frozen_string_literal: true
require "json"

module Utils
  TAXON = { "human" => "9606", "mouse" => "10090" }
  ASSEMBLY = { "human" => "GRCh38", "mouse" => "GRCm38" } # mm10

  # --- Prefix block ---
  def self.prefixes
    <<~TTL
@prefix fanta:    <https://fanta.bio/cre/> .
@prefix reftss:   <https://reftss.riken.jp/reftss/TSS:> .
@prefix fantao:   <https://fanta.bio/ontology/> .
@prefix dct:      <http://purl.org/dc/terms/> .
@prefix skos:     <http://www.w3.org/2004/02/skos/core#> .
@prefix obo:      <http://purl.obolibrary.org/obo/> .
@prefix ncbigene: <http://identifiers.org/ncbigene/> .
@prefix hgnc:     <http://identifiers.org/hgnc/> .
@prefix ensembl:  <http://identifiers.org/ensembl/> .
@prefix refseq:   <http://identifiers.org/refseq/> .
@prefix insdc:    <http://identifiers.org/insdc/> .
@prefix mgi:      <http://identifiers.org/mgi/> .
@prefix uniprot:  <http://purl.uniprot.org/uniprot/> .
@prefix sra:      <http://identifiers.org/insdc.sra/> .
@prefix hco:      <http://identifiers.org/hco/> .
@prefix faldo:    <http://biohackathon.org/resource/faldo#> .
@prefix tax:      <http://identifiers.org/taxonomy/> .
@prefix sio:      <http://semanticscience.org/resource/> .
@prefix rdf:      <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs:     <http://www.w3.org/2000/01/rdf-schema#> .
@prefix screen:   <https://screen.encodeproject.org/search/?assembly=GRCh38&q=> .
@prefix foaf:     <http://xmlns.com/foaf/0.1/> .

    TTL
  end
  
  # --- Utility functions ---
  def self.esc(s)
    s.to_s.gsub("\\", "\\\\").gsub('"', '\"').gsub("\n", "\\n")
  end

  def self.to_int_or_nil(v)
    return v if v.is_a?(Integer)
    return v.to_i if v.is_a?(String) && v.strip =~ /\A-?\d+\z/
    nil
  end

  def self.load_symbol_to_geneid(tsv_path)
    map = {}
    return map unless File.file?(tsv_path)
    File.foreach(tsv_path, chomp: true).with_index do |line, i|
      next if i.zero? && line.downcase.include?("gene") && line.downcase.include?("symbol")
      cols = line.split("\t", 2)
      next unless cols.size == 2
      gene, symbol = cols[0].strip, cols[1].strip
      next if gene.empty? || symbol.empty?
      gid = gene.split("/").last # フルURIなら末尾だけにする
      map[symbol] = gid
    end
    map
  end

  def self.chrom_number(chrom_str)
    c = chrom_str.to_s.sub(/\Achr/i, "")
    c = "MT" if c.upcase == "M"
    c
  end

  def self.id_kind(id)
    return :ensembl if id =~ /\AENS[TG]\w+\.\d+\z/i
    return :refseq  if id =~ /\A(NM|NR|XM|XR)_\d+(\.\d+)?\z/i
    :insdc
  end

  # --- Record to Turtle ---
  def self.record_to_ttl(rec, species, sym2gene)
    taxid = TAXON[species]
    asm   = ASSEMBLY[species]

    cre_id   = rec["cre_id"]
    cre_name = rec["cre_name"]

    subj = "fanta:#{cre_id}"
    buf  = []

    # CRE 本体
    buf << "#{subj} a fantao:CisRegulatoryElement ;"
    buf << "  dct:identifier \"#{esc(cre_id)}\" ;"
    buf << "  rdfs:label \"#{esc(cre_name)}\" ;" if cre_name
    Array(rec["cre_old_names"]).each { |alt| buf << "  skos:altLabel \"#{esc(alt)}\" ;" }
    buf << "  obo:RO_0002162 tax:#{taxid} ;"

    # FALDO location
    chrom = rec["cre_chrom"]
    start_i = to_int_or_nil(rec["cre_chrom_start"])
    end_i   = to_int_or_nil(rec["cre_chrom_end"])
    if chrom && start_i && end_i
      chr = chrom_number(chrom)
      buf << "  faldo:location ["
      buf << "    a faldo:Region ;"
      buf << "    faldo:begin [ a faldo:ExactPosition ; faldo:position #{start_i} ; faldo:reference hco:#{esc(chr)}##{asm} ] ;"
      buf << "    faldo:end   [ a faldo:ExactPosition ; faldo:position #{end_i} ; faldo:reference hco:#{esc(chr)}##{asm} ]"
      buf << "  ] ;"
    end

    # Promoter
    ncbi_ids      = Array(rec["tss_ncbi_geneids"])
    hgnc_mgi_ids  = Array(rec["tss_hgnc_mgi_ids"])
    uniprot_ids   = Array(rec["tss_uniprot_ids"])
    gene_names    = Array(rec["tss_gene_names"])
    gene_symbols  = Array(rec["tss_gene_symbols"])
    gene_synonyms = Array(rec["tss_gene_synonyms"])

    unless ncbi_ids.empty? && hgnc_mgi_ids.empty? && uniprot_ids.empty? &&
           gene_names.empty? && gene_symbols.empty? && gene_synonyms.empty?
      buf << "  fantao:hasPromoter ["
      buf << "    a fantao:Promoter ;"
      ncbi_ids.each do |gid|
        buf << "    rdfs:seeAlso [ a fantao:NcbiGene ; rdfs:seeAlso ncbigene:#{esc(gid)} ; dct:identifier \"#{esc(gid)}\" ] ;"
      end
      hgnc_mgi_ids.each do |rid|
        if rid =~ /\AHGNC:(\d+)\z/i
          buf << "    rdfs:seeAlso [ a fantao:Hgnc ; rdfs:seeAlso hgnc:#{$1} ; dct:identifier \"#{$1}\" ] ;"
        elsif rid =~ /\AMGI:(\d+)\z/i
          buf << "    rdfs:seeAlso [ a fantao:Mgi ; rdfs:seeAlso mgi:#{$1} ; dct:identifier \"#{$1}\" ] ;"
        end
      end
      uniprot_ids.each do |uid|
        buf << "    rdfs:seeAlso [ a fantao:UniProt ; rdfs:seeAlso uniprot:#{esc(uid)} ; dct:identifier \"#{esc(uid)}\" ] ;"
      end
      buf << "    rdfs:label \"#{esc(gene_symbols.first)}\" ;" if gene_symbols.first
      gene_synonyms.each { |syn| buf << "    skos:altLabel \"#{esc(syn)}\" ;" }
      buf << "    dct:alternative \"#{esc(gene_names.first)}\" ;" if gene_names.first
      buf[-1] = buf.last.chomp(";") unless buf.empty?
      buf << "  ] ;"
    end

    # RefTSS
    Array(rec["reftss_tss"]).each do |rt|
      Array(rt["tss_id"]).each do |rid|
        buf << "  fantao:hasRefTss [ a fantao:ReferenceTss ; rdfs:seeAlso reftss:#{esc(rid)} ; dct:identifier \"#{esc(rid)}\" ] ;"
      end
    end

    nearest_ids_set = Array(rec["tss_nearest_transcript_ids"]).to_h { |x| [x, true] }

    # All TSS transcripts
    Array(rec["tss_transcripts"]).each do |row|
      tid = row["transcript_id"]
      dist = to_int_or_nil(row["transcript_distance"])
      next unless tid
      is_nearest = nearest_ids_set[tid]
      
      buf << "  fantao:hasTssTranscript ["
      if is_nearest
        buf << "    a fantao:TssTranscript, fantao:NearestTssTranscript ;"
      else
        buf << "    a fantao:TssTranscript ;"
      end
      case id_kind(tid)
      when :ensembl
        buf << "    rdfs:seeAlso [ a fantao:Ensembl ; rdfs:seeAlso ensembl:#{esc(tid)} ; dct:identifier \"#{esc(tid)}\" ] ;"
      when :refseq
        buf << "    rdfs:seeAlso [ a fantao:RefSeq ; rdfs:seeAlso refseq:#{esc(tid)} ; dct:identifier \"#{esc(tid)}\" ] ;"
      else
        buf << "    rdfs:seeAlso [ a fantao:Insdc ; rdfs:seeAlso insdc:#{esc(tid)} ; dct:identifier \"#{esc(tid)}\" ] ;"
      end
      if dist
        buf << "    sio:SIO_000216 [ a fantao:TssDistance ; sio:SIO_000300 #{dist} ; sio:SIO_000221 obo:UO_0000244 ] ;"
      end
      buf[-1] = buf.last.chomp(";")
      buf << "  ] ;"
    end

    # SCREEN cCREs
    Array(rec["screen_ccres"]).each do |sc|
      cid, ctyp = sc["screen_ccre_id"], sc["screen_ccre_type"]
      next unless cid
      buf << "  fantao:hasOverlappedScreenCcre ["
      buf << "    a fantao:ScreenCcre ;"
      buf << "    dct:identifier \"#{esc(cid)}\" ;"
      buf << "    rdfs:label \"#{esc(ctyp)}\" ;" if ctyp
      buf << "    foaf:page screen:#{esc(cid)}"
      buf << "  ] ;"
    end

    # FANTOM5 cage peaks
    Array(rec["fantom5_cage_peaks"]).each do |fcp|
      fid, fname = fcp["cage_peak_id"], fcp["cage_peak_name"]
      next unless fid
      buf << "  fantao:hasOverlappedFantom5CagePeak ["
      buf << "    a fantao:Fantom5CagePeak ;"
      buf << "    dct:identifier \"#{esc(fid)}\" ;"
      buf << "    rdfs:label \"#{esc(fname)}\""
      buf << "  ] ;"
    end

    # FANTOM5 enhancers
    Array(rec["fantom5_enhancers"]).each do |fe|
      fids = fe["enhancer_id"]
      next unless fids
      fids.each do |fid|
        buf << "  fantao:hasOverlappedFantom5Enhancer [ a fantao:Fantom5Enhancer ; dct:identifier \"#{esc(fid)}\" ] ;"
      end
    end

    # ChIP-Atlas antigens
    Array(rec["chip_atlas_antigens"]).each do |ag|
      sym = ag["antigen"]
      mx  = to_int_or_nil(ag["maxqscore"])
      exs = Array(ag["experiments"])
      buf << "  fantao:hasOverlappedAntigen ["
      buf << "    a fantao:ChipAtlasAntigen ;"
      if sym && (gid = sym2gene[sym])
        buf << "    rdfs:seeAlso ncbigene:#{esc(gid)} ;"
      end
      buf << "    rdfs:label \"#{esc(sym)}\" ;" if sym
      buf << "    sio:SIO_000216 [ a fantao:MaxQscore ; sio:SIO_000300 #{mx} ] ;" if mx
      exs.each do |ex|
        sid, qsc = ex["id"], to_int_or_nil(ex["qscore"])
        next unless sid
        buf << "    fantao:experiment ["
        buf << "      a fantao:Experiment ;"
        buf << "      rdfs:seeAlso sra:#{esc(sid)} ;"
        buf << "      dct:identifier \"#{esc(sid)}\" ;"
        buf << "      sio:SIO_000216 [ a fantao:Qscore ; sio:SIO_000300 #{qsc} ]" if qsc
        buf << "    ] ;"
      end
      buf[-1] = buf.last.chomp(";")
      buf << "  ] ;"
    end

    buf[-1] = buf.last.chomp(";") + "." if buf.last
    buf.join("\n") + "\n\n"
  end
end
