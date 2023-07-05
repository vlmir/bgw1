# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Taxon.t'

#########################

use Test::More tests => 10;

#########################

use strict;
use Carp;
use warnings;

BEGIN {
	unshift @INC, '/norstore/user/mironov/git/bin/onto-perl/lib';
	push @INC, '/norstore/user/mironov/git/bgw';
}

my $verbose = 1;
$Carp::Verbose = 1 if $verbose;
my $real_test = 0;

use OBO::Parser::OBOParser;
use OBO::Parser::Taxon;
use OBO::Parser::PipelineSubs qw( print_obo read_map benchmark );
use Data::Dumper;

my ( $start_time, $step_time, $msg );
$start_time = time;

my $obo_parser = OBO::Parser::OBOParser->new ( );
my $taxon = OBO::Parser::Taxon->new ( );
ok ( $taxon );
my $data_dir = "./t/data";
my $in_onto_path = "$data_dir/test.obo";
my $onto = $obo_parser->work ( $in_onto_path );

$data_dir = '/norstore/project/git/workspace/data/download/taxon' if $real_test;
########################################################################
$step_time = time;
my $ncbi_nodes_path = "$data_dir/nodes_dummy.dmp";
$ncbi_nodes_path = "$data_dir/nodes.dmp" if $real_test;
my $nodes = $taxon->parse ( $ncbi_nodes_path );
ok ( %{$nodes} );
ok ( my @nodes = keys %{$nodes} );
ok ( @nodes == 8 ) unless $real_test;
$msg = 'OK'; benchmark ( $start_time, $msg, 0 ) if $real_test;
########################################################################
$step_time = time;
my $ncbi_names_path = "$data_dir/names_dummy.dmp";
$ncbi_names_path = "$data_dir/names.dmp" if $real_test;
my $name_type = 'scientific name';
my $names = $taxon->parse ( $ncbi_names_path, $name_type );
ok ( %{$names} );#print Dumper ( $names );
ok ( my @names = keys %{$names} );
ok ( @names == 10 ) unless $real_test;
$msg = 'OK'; benchmark ( $start_time, $msg, 0 ) if $real_test;
########################################################################
unless ( $real_test ) {
	my $parent = $onto->get_term_by_id ( 'GRAO:0000001' );
	my @taxon_ids = ( '3702' );
	# work
	my $result = $taxon->taxonomy2obo ( 
		$onto, 
		$nodes, 
		$names,
		$parent,
		\@taxon_ids, 
	 );
	ok ( %{$result} );
	# terms
	ok ( $onto->has_term ( $onto->get_term_by_name ( "Mikel" ) ) );
	print_obo ( $onto, "$data_dir/test.0.obo" ) if $verbose;
}
########################################################################
$step_time = time;
my ( $rdf_path , $base, $namespace ) = ( "$data_dir/taxonomy.rdf", 'http://www.semantic-systems-biology.org/', 'SSB' );
#~ ok ( $taxon->taxonomy2rdf ( $ncbi_names_path, $ncbi_nodes_path, $out_file_path, $base, $namespace ) );
ok ( $taxon->taxonomy2rdf ( $nodes, $names, $rdf_path, $base, $namespace ) );
$msg = 'OK'; benchmark ( $start_time, $msg, 0 ) if $real_test;
########################################################################
$msg = "DONE $0  "; benchmark ( $start_time, $msg, 1 ) if $real_test;
