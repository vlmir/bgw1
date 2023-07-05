#!/usr/bin/perl

# use 5.010;
use strict;
use warnings;
use Carp;
$Carp::Verbose = 1;

my ( $obof_list, $cvs_list ) = @ARGV;
open my $OBOF, '<', $obof_list;
open my $CVS, '<', $cvs_list;
my @obof;
my @cvs;
while ( <$OBOF> ) {
	my @line = split;
	push @obof, $line [0];
}

while ( <$CVS> ) {
	my @line = split /\//;
	my @file_name = split /\./, $line [-1];
	push @cvs, $file_name [0];
}

my ( @found, @not_found );
foreach my $obof ( @obof ) {
	my $count = 0;
	foreach my $cvs ( @cvs ) {
		if ( $cvs eq $obof ) {
			push @found, $cvs;
			$count++;
			last;
		}
	}
	push @not_found, "$obof\n" if ! $count;
}
my $not_found = @not_found;
print "@not_found";


