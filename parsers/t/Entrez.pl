#! /usr/bin/perl
BEGIN {
	my @homes = (
	'/home/mironov/git/usr/bgw', 
	);
	push @INC, @homes;
}
use Carp;
use strict;
use warnings;
use Test::More tests => 6;
my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};
use parsers::Entrez;
my $entrez = parsers::Entrez-> new ( );
ok ( $entrez );
use auxmod::SharedSubs qw( 
read_map 
print_counts 
);
my $base_dir = '../tdata';
my $data_dir = "$base_dir/entrez";
my $map_dir = "$base_dir/maps";
my $in_path;
my $map_path;
my $map;
my $data;
###############################################################################
# data added incrementally in 3 steps
# ATTN: do NOT change the order of the next 3 steps !
####################### parse_genes ######################################
$map_path = "$map_dir/up-gi.map";
ok ( $map = read_map ( $map_path, 1 ) ); # [gnid => [upacs]}
#print Dumper($map);
$in_path = "$data_dir/gene_info.30970";
ok ( $data = $entrez-> parse_genes ( $in_path, $map ) ); 
# print Dumper ( $data );
print_counts ( $data ) if $verbose;
######################### gene2accession ###############################
# !!! the test file contains already versioned UP ACs !!!
$in_path = "$data_dir/gene2accession.30970";
$map_path = "$data_dir/gene2uniprot.30970";
ok ( $map = read_map ( $map_path, 2 ) );
ok ( $data = $entrez-> parse_accs ( $in_path, $data, $map ) );
# print Dumper ( $data );
print_counts ( $data ) if $verbose;
############################ gene2ensembl ##############################
$in_path = "$data_dir/gene2ensembl.30970";
ok ( $data = $entrez-> parse_ensembl ( $in_path, $data ) );
#~ print_counts ( $data );
########################################################################
## the expected counts after running the first 2 functions (the 3rd one does not add entries)
#~ GENES:geneId 1
#~ LOG:noUpAc 6
#~ PROTS:proteinAc 8
#~ RNAS:rnaAc 4
#~ TAXA:taxonId 1
#~ UNIPROT:UniProtAc 2
########################## entrez2rdf ##################################

my $out_path = "$data_dir/entrez.ttl";
$entrez-> entrez2ttl ( $data, $out_path, );

############################## entrez2onto ##############################
