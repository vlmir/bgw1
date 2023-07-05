# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Uniprot.t'
#########################

use Test::More tests => 21;

#########################

BEGIN {
	push @INC, '/home/mironov/git/bgw', '/norstore_osl/home/mironov/git/bgw';
}
use Carp;
use strict;
use warnings;

use auxmod::SharedSubs qw( 
print_obo 
read_map 
print_counts 
benchmark 
open_write
write_ttl_preambule
);
use auxmod::SharedVars qw( 
%uris
%nss
);

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
}

use OBO::Parser::OBOParser;
use parsers::Uniprot;
use parsers::Obof;

my $obo_parser = OBO::Parser::OBOParser->new ( );
my $uniprot = parsers::Uniprot->new ( );
my $obof = parsers::Obof -> new ();
ok ( $uniprot ); #1

my $fs;

my ($data_dir, $up_dat_path, $up_map_path, $out, $data );
$data_dir = "./t/data";
$up_map_path = "$data_dir/up.map";
$up_dat_path = "$data_dir/up.dat";
############################## filter_dat ####################################

my @data_files = ("$data_dir/up.dat");
my $dat_out_path = "$data_dir/up.flt.dat";
$out = $uniprot-> filter_dat ( \@data_files, $dat_out_path, 284812, read_map($up_map_path) );
ok ( $out ); #2

my $mod_file_path = "$data_dir/mod_test.obo";
my $syns = $obof -> map2id ( $mod_file_path, 'synonym' ); 
# print Dumper ( $syns );
############################ parse #######################################
my $gnid2upac_path = "$data_dir/gnid2upac.out"; # for writing
$data = $uniprot-> parse ( $up_dat_path, $gnid2upac_path, $syns );
ok ( ( keys %{$data} ) == 5 ); #3
#print Dumper (  $data );
print_counts ( $data );
# redifined with real data for testing
ok ( keys %{$data->{'Protein'}{'AC'}} == 4 ); #4
ok ( keys %{$data->{'Taxon'}{'NCBI_TaxID'}} == 3 ); #5
ok ( keys %{$data->{'DISEASE'}{'MIM'}} == 1 ); #6
ok ( keys %{$data->{'FT'}{'LIPID'}} == 0 ); #7
ok ( keys %{$data->{'FT'}{'MOD_RES'}} == 3 ); #8
############################## get_fasta #####################################
my $fasta_out_path = "$data_dir/up.fst";
$out = $uniprot->get_fasta ( $up_dat_path, $fasta_out_path, 10, read_map($up_map_path) );
ok ( 1 ); #9

############################ uniprot2onto ####################################
my $in_onto_path = "$data_dir/test.obo";
my $onto = $obo_parser->work ( $in_onto_path );
$onto->name('cco');
my $onto_name = $onto->name();
print_obo ( $onto, "$data_dir/test.0.obo" ) if $verbose;
# my @keys = ( 'bml2txn', 'prt2ptm', 'prt2dss' );
$out = $uniprot-> uniprot2onto ( $onto, $data, ); # print Dumper ( $out );
foreach my $gnid ( sort keys %{$out} ) {
# 	map { print "$gnid\t$_\n" } sort keys %{$out->{$gnid}};
}
# protein with 2 genes
# the tests below down to print_obo() are still name space sensitive
ok ( my $prot = $onto->get_term_by_name ( 'EF2_SCHPO' ) ); #10
# 	ok ( my $txn = $onto->get_term_by_name ( 'Schizosaccharomyces pombe' ) );#13
ok ( my $txn = $onto->get_term_by_id ( 'NCBITaxon:284812' ) );#11
my ( @heads, $rel );
$rel = $onto->get_relationship_type_by_id ( 'inheres_in' );
@heads = @{$onto->get_head_by_relationship_type ( $prot, $rel ) };
ok ( @heads = 1 ); #12
ok ( my $prot_mod1 = $onto->get_term_by_name ( 'O-phospho-L-serine' ) ); #13
ok ( my $prot_mod2 = $onto->get_term_by_name ( 'O-phospho-L-threonine' ) ); #14
ok ( my $prot_mod3 = $onto->get_term_by_name ( "2'-[3-carboxamido-3-(trimethylammonio)propyl]-L-histidine" ) ); #15
$rel = $onto->get_relationship_type_by_id ( 'bearer_of' );
@heads = @{$onto->get_head_by_relationship_type ( $prot, $rel )};
ok ( @heads == 3 ); #16 # TODO check it !!
# $rel = $onto->get_relationship_type_by_id ( 'occurs_in' );
# @heads = @{$onto->get_head_by_relationship_type ( $prot_mod1, $rel )};
# ok ( @heads == 1 ); #16
ok ( my $dss = $onto->get_term_by_name ( 'Stevens-Johnson syndrome' ) ); #17
$rel = $onto->get_relationship_type_by_id ( 'involved_in' );
@heads = @{$onto->get_head_by_relationship_type ( $prot, $rel ) };
ok ( @heads == 1 );	#18
ok ( keys %{$out} == 3 ); #19

############################ parseIdMap ######################################
my $idmap_path = "$data_dir/schpo.xrf";
my %xdbs2up; # { xdbname =>  { xdbid => [upacs] } }, to be used by gene2onto()
my $idmap = $uniprot-> parseIdMap ( $idmap_path );
foreach my $upac ( keys %{$idmap} ) {
	my $prt = $out->{$upac} or next; # filtering
	my $dbs = $idmap->{$upac};
	foreach my $dbname ( keys %{$dbs} ) {
		my @dbids = @{$dbs->{$dbname}}; # ref to an array
		map { push @{$xdbs2up{$dbname}{$_}}, $upac } @dbids;
		map { $prt->xref_set_as_string ( "[$dbname:$_]" ) } @dbids unless $dbname eq 'UniProtKB-ID';
	}
}
#~ print Dumper ( \%xdbs2up );
ok ( $prot-> xref_set_as_string ( "[GeneID:2539544, GeneID:3361483]" ) ); #20
print_obo ( $onto, "$data_dir/test.5.obo" ) if $verbose;

############################# uniprot2rdf ####################################
my $ttl_file_path = "$data_dir/up.test.ttl";
ok ( $uniprot-> uniprot2ttl ( $data, $ttl_file_path, ) ); #21
