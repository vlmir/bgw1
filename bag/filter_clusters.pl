#!/usr/local/bin/perl -w
=head2 filter_clusters.pl

  Usage    - perl filter_clusters.pl input_orthomcl_file < uniprot_file(s) > output_orthomcl_file
  Args     - orthoMCL output file
  Function - filters out from an orthoMCL output file clusters containing proteins from  the uniprot file(s) 
  
=cut
use strict;
use warnings;
use Carp;
use SWISS::Entry;

my $orthomcl_file = shift @ARGV;
open my $FILE, '<', $orthomcl_file or croak "Can't open '$orthomcl_file': $!\n";
my @clusters = <$FILE>;
my %prot_names;

#local $/ = "\n//\n";
#while (<>) {
#	my $prot_name = ${SWISS::Entry->fromText($_)->IDs()->{list}}[0];
#	for (my $i=0; $i < scalar(@clusters); $i++) {
#		my $cluster = $clusters[$i];
#		$cluster =~/$prot_name/xms ? print $cluster && splice (@clusters, $i, 1) : next;
#	}
#}
{
	local $/ = "\n//\n";
	while (<>) {
		my $prot_name = ${SWISS::Entry->fromText($_)->IDs()->{list}}[0];
		$prot_names{$prot_name} = 1;
	}
}
for (my $i=0; $i < scalar(@clusters); $i++) {
	my $cluster = $clusters[$i];
	foreach my $prot_name (keys %prot_names) {
		$cluster =~/$prot_name/xms ? print $cluster && splice (@clusters, $i, 1) : next;
	}
}