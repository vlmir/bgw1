#! /usr/bin/perl
BEGIN {
	my @homes = (
	'/home/mironov/git/usr/bgw', 
	'/norstore/user/mironov/git/usr/bgw', 
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

my (
$indir, # dir containing .obo files, no trailing slash
) = @ARGV;
my @files = `ls $indir/*.obo`;
use parsers::Obof;
my $obof = parsers::Obof->new ( );

use OBO::Parser::OBOParser; # needed 
my $parser = OBO::Parser::OBOParser->new ( ); # needed 
foreach my $file (@files) {
	chomp($file);
	my $onto = $parser-> work ( $file ); # needed 
	next unless $onto;
	substr($file, -3, 3) = 'ttl'; # the right way of changing exptentions !!
	my $map = $obof-> obo2ttl ( $onto, $file, 'rdfs' );
}
