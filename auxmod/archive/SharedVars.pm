package auxmod::SharedVars;

use Carp;
use strict;
use warnings;
use Exporter;

########################################################################
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
%add_ptntm
%prns
%olders
%organisms
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

# my $base_dir = '/projects/NS9017K';
my $base_dir = '/tos-project2/NS9017K/NORSTORE_OSL_DISK/NS9017K';
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
############################## Sufficient for BGW ##############################################


# TODO mv all vars from UploadVars.pm here ??
#
our %uris = (
'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 
'rdfs' => 'http://www.w3.org/2000/01/rdf-schema#', 
'owl' => 'http://www.w3.org/2002/07/owl#', 
'skos' => 'http://www.w3.org/2004/02/skos/core#',
'oboInOwl' => 'http://www.geneontology.org/formats/oboInOwl#', 
'bfo' => 'http://purl.obolibrary.org/obo/', 
'ro' => 'http://purl.obolibrary.org/obo/', 
'go' => 'http://purl.obolibrary.org/obo/', 
'mi' => 'http://purl.obolibrary.org/obo/', 
'obo' => 'http://purl.obolibrary.org/obo/', 
'sio' => 'http://semanticscience.org/resource/',  # resolvable (2014-09-29)
'ncit' => 'http://identifiers.org/ncit/',
'uniprot' => 'http://identifiers.org/uniprot/',
'ncbigene' => 'http://identifiers.org/ncbigene/',
'ensembl' => 'http://identifiers.org/ensembl/',
'omim' => 'http://identifiers.org/omim/', 
'intact' => 'http://identifiers.org/intact/',
'goa' => 'http://identifiers.org/goa/',
'pubmed' => 'http://identifiers.org/pubmed/',
'hgnc' => 'http://identifiers.org/hgnc.symbol/',
'ssb' => 'http://www.semantic-systems-biology.org/ssb/', 
'bgw' => 'http://ssb.biogateway.eu/', 
'tsfr' => 'http://ssb.biogateway.eu/tsfr/', 
'rgts' => 'http://ssb.biogateway.eu/rgts/', 
'schema' => 'http://schema.org/',
);
our %nss = (
# use these as well in properties for xrefs
# as used at identifiers.org
'tsfr' => 'NCIt',
'gn' => 'NCBIGene',
'ptn' => 'UniProt',
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

## changed prt -> ptn GLOBALLY!
our %prns = (
## used in ALL parsers TODO replace with %olders
'ptn' => ['SIO:010043', 'protein'],
'ptm' => ['PR:000025513', 'modified amino-acid residue'],
'dss' => ['OGMS:0000031', 'disease'], # explicitely only in seed.pl TODO change to SIO_010299
'txn' => ['SIO:010000', 'organism'],
'gn' => ['SIO:010035', 'gene'],
'ppi' => ['MI:0190', 'molecular interaction'], # we rename it 'interaction type' => 'molecular interaction'
);

our %olders = (
'ptn' => ['SIO', '010043', 'protein'],
'ptm' => ['PR', '000025513', 'modified amino-acid residue'],
'txn' => ['SIO', '010000', 'organism'],
'gn' => ['SIO', '010035', 'gene'],
'ppi' => ['MI', '0190', 'molecular interaction'], # we rename it 'interaction type' => 'molecular interaction'
## added 2018
'tsfr' => ['NCIt', 'C17207', 'transcription factor'],
'pcx' => ['GO', '0032991', 'protein complex'],
'ice' => ['SIO', '010015', 'information content entity'],
'dss' => ['SIO', '010299', 'disease'],
# 'rgts' => ['GO', '0006357', 'regulation of transcription from RNA polymerase II promoter'],
'rgts' => ['SIO', '001125', 'regulation of transcription'],
'pur' => ['SIO', '010295', 'process up-regulation'],
'pdr' => ['SIO', '010296', 'process down-regulation'],
# not yet used
# 'mrna' => ['SIO', '010099', 'messanger RNA'], # TODO Integrate in APOs ?
# 'cc' => ['GO', '0005575', 'cellular component'], # > 1 gene product!
# 'mf' => ['GO', '0003674', 'molecular function'],
# 'bp' => ['GO', '0008150', 'biological process'],
# 'gp' => ['NCIt', 'C26548', 'gene product'], # including various combinations
# 'pyp' => ['CHEBI', '15841', 'polypeptide'], # TODO add to UP
# depricated
# 'rtn' => ['GO', '0000122', 'negative regulation of transcription from RNA polymerase II promoter'],
# 'rtp' => ['GO', '0045944', 'positive regulation of transcription from RNA polymerase II promoter'],
);

## Object properties
our %props = (
## used in all parsers
# used in APO-2015  and BGW-2015
'cls2prn' => ['rdfs', 'subClassOf', 'is subclass of'],
'ppy2prn' => ['rdfs', 'subPropertyOf', 'is subproperty of'],
'ins2prn' => ['rdf', 'type', 'has type'],
'gn2txn' => ['RO', '0000052', 'inheres in'], #the same semantics as BFO
'ptn2txn' => ['RO', '0000052', 'inheres in'], #the same semantics as BFO
'ptn2dss' => ['RO', '0002331', 'involved in'], # not in SIO or BFO2 
'ptn2ptm' => ['RO', '0000053', 'bearer of'], # e.g. protein -> modified residue, the same semantics as BFO # NOT 'all-some'
'ptn2bp' => ['RO', '0002331', 'involved in', 'biological_process'], # comes from GPA # TODO fix this quick fix ?
'ptn2cc' => ['BFO', '0000050', 'part of', 'cellular_component'], # comes from GPA, present in RO
'ptn2mf' => ['RO', '0002327', 'enables', 'molecular_function'], # comes from GPA
'gn2gp' => ['SIO', '010078', 'encodes'],
'ppi2ptn' => ['SIO', '000139', 'has agent'], # Attn: by def between a process and an entity ! Not in BFO
'orl2orl' => ['SIO', '000558', 'is orthologous to'],
'prl2prl' => ['SIO', '000630', 'is paralogous to'],
# added 2016 
'ptn2ptn' => ['RO', '0002436', 'molecularly interacts with'], # intact
# added 2018
'rgr2trg' => ['SIO', '001154', 'regulates'], # tftg
'acr2trg' => ['SIO', '001401', 'positively regulates'], # tftg
'spr2trg' => ['SIO', '001402', 'negatively regulates'], # tftg
'stm2evd' => ['SIO', '000772', 'has evidence'], # PubMed only
'sth2src' => ['SIO', '000253', 'has source'], # tftg; description: has source is a relation between an entity and another entity from which it stems from. 
'sth2mtd' => ['rdfs', 'isDefinedBy', 'is defined by'],
'cc2ptn' => ['BFO', '0000051', 'has part'],
'mbr2lst' => ['RO', '0002350', 'is member of'],
'sth2sth' => ['SIO', '000001', 'is related to'], # grandparent of the 4 below
'rgts2tsfr' => ['SIO', '000139', 'has agent'],
'rgts2gn' => ['SIO', '000291', 'has target'],
## not yet used
'tf2rt' => ['SIO', '000063', 'is agent in'],
'tg2rt' => ['SIO', '000062', 'is participant in'], # parent of 'is agent in'
'ptn2mf' => ['RO', '0002329', 'part of structure that is capable of'],
# 'ptn2cc' => ['SIO', '000068', 'is part of', 'cellular_component'],
#'xrf4homo' => ['skos', 'closeMatch', 'has close match'],
#'xrf4hetero' => ['skos', 'relatedMatch', 'has related match'],
#'stm2ori' => ['schema', 'evidenceOrigin', 'has evidence origin'], # iso 'has source'? TODO
#'sth2pvd' => ['schema', 'provider', 'has provider'],
## depricated
# 'rgr2trg' => ['RO', '0002448', 'molecularly controls'], # tftg
# 'acr2trg' => ['RO', '0002450', 'molecularly increases activity of'], # tftg
# 'spr2trg' => ['RO', '0002449', 'molecularly decreases activity of'], # tftg
# 'stm2evd' => ['skos', 'reference', 'has reference'], # PubMed only
# 'sth2sth' => ['skos', 'related', 'has related'],
# 'rgts2gn' => ['SIO', '000132', 'has participant'], # parent of 'has agent'
# 'mbr2lst' => ['schema', 'memberOf', 'is member of'],
);

## Annotation properties
our %aprops = (
## used in APO-2015  and BGW-2015
'sth2lbl' => ['skos', 'prefLabel', 'has preferred label'],
'sth2dfn' => ['skos', 'definition', 'has definition'],
'sth2syn' => ['skos', 'altLabel', 'has alternative label'],
# added 2018
'evd2lvl' => ['schema', 'evidenceLevel', 'has evidence level'],
# not used

);

################################### for APOs ###################################
# TODO should be taken from UP
our %organisms = (
	'559292' => [ 'Saccharomyces cerevisiae', 'An organism of the species Saccharomyces cerevisiae', 'yeast'],
	'284812' => [ 'Schizosaccharomyces pombe', 'An organism of the species Schizosaccharomyces pombe', 'schpo'],
	'3702' => [ 'Arabidopsis thaliana', 'An organism of the species Arabidopsis thaliana', 'arath'],
	'6239' => [ 'Caenorhabditis elegans', 'An organism of the species Caenorhabditis elegans', 'caeel'],
	'7227' => [ 'Drosophila melanogaster', 'An organism of the species Drosophila melanogaster', 'drome'],
	'8364' => [ 'Xenopus tropicalis', 'An organism of the species Xenopus tropicalis', 'xentr'],
	'9606' => [ 'Homo sapiens', 'An organism of the species Homo sapiens', 'human'],
	'10090' => [ 'Mus musculus', 'An organism of the species Mus musculus', 'mouse'],
	'10116' => [ 'Rattus Norvegicus', 'An organism of the species Rattus Norvegicus', 'rat'],
);

our %add_ptntm = ( # only for APOs
'ptn2bp' => 'involved_in',
);

################################################################################################

1;
