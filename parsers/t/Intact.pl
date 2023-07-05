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
use parsers::Intact;
my $intact = parsers::Intact->new ( );
ok ( $intact );
use auxmod::SharedSubs qw( 
read_map
print_counts 
);
my $base_dir = '../tdata';
my $data_dir = "$base_dir/intact";
my $map_dir = "$base_dir/maps";
my $in_path;
my $map_path;
my $map;
my $data;
###############################################################################

$map_path = "$map_dir/up.map";
$map = read_map ( $map_path );
ok ( $map );
$in_path = "$data_dir/intact.dat";
$data = $intact->parse (
$in_path,
$map
);
ok ($data);
print_counts ( $data ) if $data;
$in_path = "$data_dir/test.dat";
$data = $intact->parse (
$in_path,
);
ok ($data);
print_counts ( $data ) if $data;
