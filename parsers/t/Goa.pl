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
use Test::More tests => 4;
my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};
use parsers::Goa;
my $parser = parsers::Goa-> new ( );
ok ( $parser );
use auxmod::SharedSubs qw( 

print_counts 
);
my $base_dir = '../tdata';
my $data_dir = "$base_dir/goa";
my $map_dir = "$base_dir/maps";
my $in_path;
my $map_path;
my $map;
my $data;
###############################################################################
# ATTN: the order of the steps is important!
my %taxon_labels = (
'9606' => 'human',
'10090' => 'mouse',
);
$in_path = "$data_dir/goa.gpi";
$map_path = "$map_dir/upac2taxid.map";
ok ( $map = $parser-> parse_gpi( $in_path, $map_path, \%taxon_labels ) );
#print Dumper ($map);
my $qlfr = 'part_of';
$in_path = $data_dir . '/goa.gpa';
ok ( $data = $parser->  parse ( 
$in_path,
$qlfr,
$map 
) );
#print Dumper ( $data );
ok ( keys %{$data} == 2 );
print_counts ( $data );

