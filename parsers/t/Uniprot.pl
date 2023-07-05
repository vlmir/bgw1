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
use Test::More tests => 12;
my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
}
use parsers::Uniprot;
my $uniprot = parsers::Uniprot->new ( );
ok ( $uniprot ); #1
use auxmod::SharedSubs qw( 
read_map 
print_counts 
);
my $base_dir = '../tdata';
my $data_dir = "$base_dir/uniprot";
my $map_dir = "$base_dir/maps";
my $in_path;
my $map_path;
my $map;
my $data;
###############################################################################

my ($out_path, $out, );
$in_path = "$data_dir/up.dat";
$map_path = "$map_dir/up.map";
############################## filter_dat ####################################

my @data_files = ($in_path);
$out_path = "$data_dir/up-flt.dat";
$out = $uniprot-> filter_dat ( \@data_files, $out_path, 284812, read_map($map_path) );
ok ( $out ); #2

use parsers::Obof;
my $obof = parsers::Obof -> new ();
my $obo_path = "$base_dir/obof/tmod.obo";
my $syns = $obof -> map2id ( $obo_path, 'synonym' ); 
ok ( $syns ); # new
# print Dumper ( $syns );
############################## get_fasta #####################################
$out_path = "$data_dir/up.fst";
$out = $uniprot->get_fasta ( $in_path, $out_path, 10, read_map($map_path) );
ok ( 1 ); #9

############################ parseIdMap ######################################
# TODO see if needed at all
$out = $uniprot-> parseIdMap ( "$data_dir/schpo.xrf" ); # seems not used
ok ( $out ); # new

############################ parse #######################################
$out_path = "$map_dir/gnid2upac.map"; # for writing
$data = $uniprot-> parse ( $in_path, $out_path, $syns );
ok ( ( keys %{$data} ) == 5 ); #3
#print Dumper (  $data );
print_counts ( $data );
# redifined with real data for testing
ok ( keys %{$data->{'Protein'}{'AC'}} == 4 ); #4
ok ( keys %{$data->{'Taxon'}{'NCBI_TaxID'}} == 3 ); #5
ok ( keys %{$data->{'DISEASE'}{'MIM'}} == 1 ); #6
ok ( keys %{$data->{'FT'}{'LIPID'}} == 0 ); #7
ok ( keys %{$data->{'FT'}{'MOD_RES'}} == 3 ); #8
############################# uniprot2rdf ####################################
$out_path = "$data_dir/up.ttl";
ok ( $uniprot-> uniprot2ttl ( $data, $out_path, ) ); #21
