#!/usr/bin/perl -w
###############################################################################################################
#  Usage    - perl 'OBO_file_name', id1', 'id2', 'id3' < input_uniprot_file 
#  Returns  - 
#  Args     - path to the file containing ontology, list of NCBI taxon IDs
#  Function - filters UniProt file by TAXON and Uniprot ID and writes a separate file for each taxon 
###############################################################################################################
use strict;
use Carp;
use warnings;

my $workspace = '/group/biocomp/cbd/users/erant/workspace/ONTO-PERL/';

BEGIN {
	unshift @INC, '/group/biocomp/cbd/users/erant/workspace/ONTO-PERL';
}

use OBO::Parser::OBOParser;

#my $start = time;
my $OBO_file = shift || die "No input ontology!", $!;
my @taxa = @ARGV; 
die "No input taxa!", $! unless @taxa;
my %out = ();
#my ($tot_recs, $filtered_recs);

# Initialize the OBO parser,load the OBO file
my $my_parser = OBO::Parser::OBOParser->new();
my $ontology = $my_parser->work($OBO_file);

local $/ = "\n//\n";

	#my $count = 0;
while(<STDIN>){
	$_ =~ /ID\s{3}(\w+_\w+)\s/ ? my $name = $1 : next;
	my $entry = $_;
	#warn $name;
    if ($ontology->get_term_by_name($name)){
		foreach my $taxon (@taxa) {
			if ($entry =~ /TaxID=$taxon;/) {
				push @{$out{$taxon}}, $entry;
				#$filtered_recs ++;				
			}
		}
    }
}


foreach (keys %out) {
	my $out_file = "up_$_.txt";
	open FH, ">$out_file" || die "Can't open file for writing!", $!;
	print FH @{$out{$_}};
	close FH;
}

#my $end = time;
#print "wrote $filtered_recs entries out of total $tot_recs in ", $end-$start, " seconds for ",scalar @taxa, " taxa\n";
