#! /usr/bin/perl
BEGIN {
	my @homes = (
	'/home/mironov/git/usr/bgw', 
	);
	push @INC, @homes;
}
use strict;
use warnings;
use Carp;
my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
}
use auxmod::SharedSubs qw( 
read_map
);

my (
$indir, # dir containing goa.dat files, no trailing slash
$ext, # string
$qlfr, # part_of | enables | involved_in 
$pth2map,
) = @ARGV;
my $map = read_map ( $pth2map );
my @files = `ls $indir/*.$ext`;
use parsers::Goa;
my $goa = parsers::Goa->new ( );

foreach my $file (@files) {
	chomp($file);
	my $data = $goa-> parse ( $file, $qlfr, $map);
}
