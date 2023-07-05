#! /usr/bin/perl
package auxmod::SharedVars;

use Carp;
use strict;
use warnings;
use Exporter;

########################################################################
# TODO clean up exports
our @ISA = qw(Exporter); # sic!
our @EXPORT = qw(
$rex_first_word
$rex_dot
$rex_semicln
$rex_prnths
$rex_brcs
$rex_brkts
$rex_dblq
$download_dir
%uris
%nss
%props
%aprops
%prns
%olders
$workspace_dir
$projects_dir
$ortho_dir
$gpi_src_file
$gpa_src_file
$gpi_txn_lst
$intact_src_file
);

## reg expressions
our $rex_first_word = qr/^(\w+)/xmso;
our $rex_second_word = qr/^\w+\W+(\w+)/xmso;
our $rex_dot = qr/^(.+?)\.(.*)/xmso; # the first dot
our $rex_semicln= qr/^(.+?);(.*)/xmso; # the first semicolon
our $rex_prnths = qr/^(.+?)\s\((.+?)\)(.*)$/xmso; # the first pair of parens
our $rex_brcs = qr/^(.+?)\s\{(.+?)\}(.*)$/xmso; # the first pair of braces
our $rex_brkts = qr/^(.+)\s\[(.+?)\](.*)$/xmso; # the last pair of brackets
our $rex_dblq = qr/"(.+?)"(.*)/xmso; # fetches the first double quoted string;
our $rex_bksl = qr/(\S*)\/(\S+)/xmso; # captures everything before and after the last slash '/'

############################## Sufficient for BGW ##############################################

# Note: replaced GLOBALLY 'ptn' => 'tlp' - 'translation product' TODO test
# TODO mv all vars from UploadVars.pm here ??
#
our %uris = (
'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 
'rdfs' => 'http://www.w3.org/2000/01/rdf-schema#', 
'owl' => 'http://www.w3.org/2002/07/owl#', 
'skos' => 'http://www.w3.org/2004/02/skos/core#',
'schema' => 'http://schema.org/',
#'oboInOwl' => 'http://www.geneontology.org/formats/oboInOwl#', 
'obo' => 'http://purl.obolibrary.org/obo/', 
'sio' => 'http://semanticscience.org/resource/',  # resolvable (2014-09-29)
'ncit' => 'http://identifiers.org/ncit/',
'uniprot' => 'http://identifiers.org/uniprot/', # strictly accs, unlike uniprot.org/uniprot/ or ncbi.nlm.nih.gov/protein/
'uniparc' => 'http://identifiers.org/uniparc/',
'ncbigi' => 'http://identifiers.org/ncbigi/gi:', # the same id for genes and prots, better avoided
'ncbitaxon' => 'http://purl.bioontology.org/ontology/NCBITAXON/',
'refseq' => 'http://identifiers.org/refseq/',
#'unigene' => 'http://www.ncbi.nlm.nih.gov/unigene',
#'omim' => 'http://identifiers.org/omim/', 
'omim' => 'http://purl.bioontology.org/ontology/OMIM/',
'orthodb' => 'https://www.orthodb.org/?query=', # accepts IDs from UP idmapping
'intact' => 'http://identifiers.org/intact/',
'goa' => 'http://identifiers.org/goa/',
'pubmed' => 'http://identifiers.org/pubmed/',
#'hgnc.symbol' => 'http://identifiers.org/hgnc.symbol/',
'kegg' => 'http://identifiers.org/kegg.genes/',
'ko' => 'http://identifiers.org/kegg.orthology/',
'embl' => 'http://identifiers.org/ena.embl/',
'ensembl' => 'http://identifiers.org/ensembl/',
'genewiki' => 'http://identifiers.org/genewiki/', # only human
'hgnc' => 'http://identifiers.org/hgnc/',
'ncbigene' => 'http://identifiers.org/ncbigene/',
'unigene' => 'http://identifiers.org/unigene/', # collection of transcripts associated with a gene
'pr' => 'http://purl.obolibrary.org/obo/PR_', 
'go' => 'http://purl.obolibrary.org/obo/GO_', 
'bgw' => 'http://rdf.biogateway.eu/', 
'gene' => 'http://rdf.biogateway.eu/gene/', 
'gn-up' => 'http://rdf.biogateway.eu/gene-uniprot/', 
#'tsf' => 'http://rdf.biogateway.eu/tsf/', # TODO check if used
'prot' => 'http://rdf.biogateway.eu/prot/', 
'up-gn' => 'http://rdf.biogateway.eu/prot-gene/', # for TF-TG
'up-up' => 'http://rdf.biogateway.eu/prot-prot/', 
'up-obo' => 'http://rdf.biogateway.eu/prot-obo/', 
'up-mim' => 'http://rdf.biogateway.eu/prot-omim/', 
'fnl' => 'http://www.biogateway.eu/fnl', # dummy TODO fix
'htri' => 'http://www.lbbc.ibb.unesp.br/htri',
'signor' => 'http://signor.uniroma2.it/',
'tfacts' => 'http://www.tfacts.org',
'trrust' => 'http://www.grnpedia.org/trrust/',
);

our %olders = (
# TODO distinction type - interaction, rank - organism
'stm' => ['rdf', 'Statement', 'triple'],
'tlp' => ['sio', 'SIO_010043', 'protein'],
'ptm' => ['obo', 'PR_000025513', 'modified amino-acid residue'],
'txn' => ['sio', 'SIO_010000', 'organism'],
'gn' => ['sio', 'SIO_010035', 'gene'],
#'ppi' => ['obo', 'MI_0190', 'molecular interaction'], # we rename it 'interaction type' => 'molecular interaction'
'ppi' => ['obo', 'INO_0000311', 'protein-protein interaction'],
## added 2018
'tsf' => ['NCIt', 'C17207', 'transcription factor'],
'tsfrx' => ['obo', 'GO_0090575', 'RNA polymerase II transcription factor complex'],
#'pcx' => ['obo', 'GO_0032991', 'protein complex'],
'dss' => ['sio', 'SIO_010299', 'disease'],
'rgts' => ['obo', 'GO_0006357', 'regulation of transcription from RNA polymerase II promoter'],
'bp' => ['obo', 'GO_0008150', 'biological process'],
# not yet used
#'pur' => ['sio', 'SIO_010295', 'process up-regulation'],
#'pdr' => ['sio', 'SIO_010296', 'process down-regulation'],
#'rgts' => ['sio', 'SIO_001125', 'regulation of transcription'],
'mi' => ['obo', 'MI_0000', 'molecular interaction'],
# 'mrna' => ['sio', 'SIO_010099', 'messanger RNA'], # TODO Integrate in APOs ?
# 'cc' => ['obo', 'GO_0005575', 'cellular component'], # > 1 gene product!
# 'mf' => ['obo', 'GO_0003674', 'molecular function'],
# 'gp' => ['NCIt', 'C26548', 'gene product'], # including various combinations
# 'pyp' => ['obo', 'CHEBI', '15841', 'polypeptide'], # TODO add to UP
# depricated
# 'role' => ['sio', 'SIO_000016', 'role'],
# 'rtn' => ['obo', 'GO_0000122', 'negative regulation of transcription from RNA polymerase II promoter'],
# 'ice' => ['sio', 'SIO_010015', 'information content entity'],
# 'rtp' => ['obo', 'GO_0045944', 'positive regulation of transcription from RNA polymerase II promoter'],
);

## Object properties
our %props = (
## used in all parsers
# used in APO-2015  and BGW-2015
'cls2prn' => ['rdfs', 'subClassOf', 'is subclass of'],
'ppy2prn' => ['rdfs', 'subPropertyOf', 'is subproperty of'],
'ins2cls' => ['rdf', 'type', 'has type'],
'tlp2ptm' => ['obo', 'RO_0000053', 'bearer of'], # e.g. protein -> modified residue, the same semantics as BFO # NOT 'all-some'
'gn2txn' => ['sio', 'SIO_000253', 'has source', 'has source is a relation between an entity and another entity from which it stems from.'],
'gp2txn' => ['sio', 'SIO_000253', 'has source', 'has source is a relation between an entity and another entity from which it stems from.'],
'gp2phn' => ['obo', 'RO_0002331', 'involved in'], # not in SIO or BFO2 
'gp2bp' => ['obo', 'RO_0002331', 'involved in', 'biological_process'], # comes from GPA # TODO fix this quick fix ?
'gp2cc' => ['obo', 'BFO_0000050', 'part of', 'cellular_component'], # comes from GPA, present in RO
'gp2mf' => ['obo', 'RO_0002327', 'enables', 'molecular_function'], # comes from GPA # not in SIO
'gn2gp' => ['sio', 'SIO_010078', 'encodes'],
'ppi2tlp' => ['sio', 'SIO_000139', 'has agent'], # Attn: by def between a process and an entity ! Not in BFO
#'orl2orl' => ['sio', 'SIO_000558', 'is orthologous to'],
#'prl2prl' => ['sio', 'SIO_000630', 'is paralogous to'],
# added 2016 
'tlp2tlp' => ['obo', 'RO_0002436', 'molecularly interacts with'], # is connected to SIO_000203 - closest
# added 2018
#'gp2cc' => ['sio', 'SIO_000093', 'is proper part of'], # to be used in GOA
#'gp2bp' => ['sio', 'SIO_000062', 'is participant in'], # to be used in GOA # parent of 'is agent in'
'bp2gp' => ['sio', 'SIO_000132', 'has participant'], #  parent of 'has agent; USED in intact.py
#'tlp2tlp' => ['sio', 'SIO_000203', 'is connected to'], # to be used in Intact
'rgr2trg' => ['obo', 'RO_0002428', 'involved in regulation of'], # tftg
'acr2trg' => ['obo', 'RO_0002429', 'involved in positive regulation of'], # tftg
'spr2trg' => ['obo', 'RO_0002430', 'involved in negative regulation of'], # tftg
'stm2evd' => ['sio', 'SIO_000772', 'has evidence'], # PubMed only
'sth2evd' => ['sio', 'SIO_000772', 'has evidence'], # PubMed only
'sth2ori' => ['schema', 'evidenceOrigin', 'has evidence origin'], # for pointing to DATA sources
'stm2ori' => ['schema', 'evidenceOrigin', 'has evidence origin'], # for pointing to DATA sources
'stm2mtd' => ['rdfs', 'isDefinedBy', 'is defined by'],
#'mbr2lst' => ['sio', 'SIO_000095', 'is member of'],
#'sth2sth' => ['sio', 'SIO_000001', 'is related to'],
#'stm2sbj' => ['sio', 'SIO_000139', 'has agent'],
#'stm2obj' => ['sio', 'SIO_000291', 'has target'],
'cls2cls' => ['owl', 'equivalentClass', 'is equivalent class of'],
## not yet used
#'cc2gp' => ['sio', 'SIO_000053', 'has proper part'],
#'xrf4homo' => ['skos', 'closeMatch', 'has close match'],
'sth2els' => ['skos', 'relatedMatch', 'has related match'],
#'sth2pvd' => ['schema', 'provider', 'has provider'],
## depricated
#'rgr2trg' => ['sio', 'SIO_001154', 'regulates'], # tftg
#'acr2trg' => ['sio', 'SIO_001401', 'positively regulates'], # tftg
#'spr2trg' => ['sio', 'SIO_001402', 'negatively regulates'], # tftg
# 'rgr2trg' => ['obo', 'RO_0002448', 'molecularly controls'], # tftg
# 'acr2trg' => ['obo', 'RO_0002450', 'molecularly increases activity of'], # tftg
# 'spr2trg' => ['obo', 'RO_0002449', 'molecularly decreases activity of'], # tftg
# 'mbr2lst' => ['schema', 'memberOf', 'is member of'],
);

## Annotation properties
our %aprops = (
## used in APO-2015  and BGW-2015
'sth2nm' => ['skos', 'prefLabel', 'has preferred label'],
'sth2dfn' => ['skos', 'definition', 'has definition'],
'sth2syn' => ['skos', 'altLabel', 'has alternative label'],
# added 2018
'sth2id' => ['skos', 'notation', 'has notation'],
'sth2val' => ['rdf', 'value', 'has value'],
'evd2lvl' => ['schema', 'evidenceLevel', 'has evidence level'],
'sth2cmt' => ['rdfs', 'comment', 'has comment'],
# not used
);

our %prns = (
## used in entre2ttl, intact2ttl, uniprot2ttl
#TODO replace with %olders
'tlp' => ['SIO:010043', 'protein'],
'ptm' => ['PR:000025513', 'modified amino-acid residue'],
'dss' => ['OGMS:0000031', 'disease'], # explicitely only in seed.pl TODO change to SIO_010299
'txn' => ['SIO:010000', 'organism'],
'gn' => ['SIO:010035', 'gene'],
'ppi' => ['MI:0190', 'molecular interaction'], # we rename it 'interaction type' => 'molecular interaction'
);
our %nss = (
# TODO mop up this mess
# used in *.pm
# use these as well in properties for xrefs
# as used at identifiers.org
'tsf' => 'NCIt',
'gn' => 'NCBIGene',
'tlp' => 'UniProt',
'dss' => 'OMIM',
'txn' => 'NCBITaxon',
'ppi' => 'IntAct',
'insdc' => 'INSDC',
'pm' => 'PubMed',
'goa' => 'GOA',
# 'ptm' => 'SSB',
'ptm' => 'MOD',
'ssb' => 'SSB',
'ens' => 'Ensembl',
);

my $base_dir = '/home/mironov'; # idun
our $workspace_dir = $base_dir.'/workspace';
our $projects_dir = "$workspace_dir/projects";
our $ortho_dir = $projects_dir . '/ortho';
# source dirs
my $data_dir = $workspace_dir.'/data';
our $download_dir = $data_dir.'/download'; # a link; adjust for each release !!!
my $goa_src_dir = "$download_dir/goa";
my $idm_src_dir = "$download_dir/idmapping";
my $up_src_dir = "$download_dir/uniprot";
my $intact_src_dir = "$download_dir/intact";
my $entrez_src_dir = "$download_dir/entrez";
my $orthodb_src_dir = "$download_dir/orthodb";
my $pazar_src_dir = "$download_dir/pazar";

our $gpi_src_file = $goa_src_dir . '/gp_information.goa_ref_uniprot';
our $gpa_src_file = $goa_src_dir . '/gp_association.goa_ref_uniprot';
our $gpi_txn_lst = $goa_src_dir . '/gpi-txn.lst';
our $intact_src_file = "$intact_src_dir/intact.txt";
our $pazar_src_file = "$pazar_src_dir/pazar.tsv";
# our $refprot_map_path = "$idm_src_dir/refprot.all"; # currently not used
# our $refprot_ids_map_path = "$idm_src_dir/refprot.upid"; # currently not used
# our $refprot_taxa_map_path = "$idm_src_dir/refprot.taxa"; # currently not used
our $gene2accession_file = "$entrez_src_dir/gene2accession-refprot";
our $gene2ensembl_file = "$entrez_src_dir/gene2ensembl-refprot";
our $gene_info_file ="$entrez_src_dir/gene_info-refprot";
################################### for APOs ###################################
