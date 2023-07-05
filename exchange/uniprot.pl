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

my (
$indir, # dir containing uniprot.dat files, no trailing slash
$modpath, # path to mod.obo for retrieving prot modification ID
) = @ARGV;
my @files = `ls $indir/*.dat`;
use parsers::Uniprot;
my $uniprot = parsers::Uniprot->new ( );
use parsers::Obof;
my $obof = parsers::Obof -> new ();
my $syns = $obof -> map2id ( $modpath, 'synonym' ); 

foreach my $file (@files) {
	my ($base, $ext) = split /\./, $file;
	my $inpath = "$base.dat";
	my $expath = "$base.json";
	my $data = $uniprot-> parse ( $inpath, $expath, $syns );
	$expath = "$base.ttl";
	$uniprot-> uniprot2ttl ( $data, $expath, );
}
