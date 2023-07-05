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
$indir, # dir containing intact.dat files, no trailing slash
$ext, # string
$pth2map,
) = @ARGV;
my $map = read_map ( $pth2map );
my @files = `ls $indir/*.$ext`;
use parsers::Intact;
my $intact = parsers::Intact->new ( );

foreach my $file (@files) {
	chomp($file);
	my $data = $intact-> parse ( $file, $map);
}
