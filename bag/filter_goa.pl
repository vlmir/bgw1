#!/usr/bin/perl -w
###############################################################################################################
#  Usage    - perl 'OBO_file_name' < input_goa_assoc_file > output_goa_assoc_file
#  Returns  - 
#  Args     - ontology with GO terms to filter against
#  Function - retreives a subset of associations containing GO terms present in the input ontology
###############################################################################################################
use strict;
use Carp;
use warnings;
use OBO::Parser::OBOParser;

#my $start = time;

my $OBO_file = shift;
my @out = ();

# Initialize the OBO parser,load the OBO file
my $my_parser = OBO::Parser::OBOParser->new();
my $ontology = $my_parser->work($OBO_file);


# Filter GOA associations 

	#my $count = 0;
while(<STDIN>){
	$_ =~ /\w/ ? my $record = $_ : next;
	@_ = split(/\t/, $record);
	foreach(@_){
		$_ =~ s/^\s+//; 
		$_ =~ s/\s+$//;
	}	        
	my $id = $_[4];
	my $prefix = 'CCO:'.$_[8]; 
	$id =~ s/GO:/$prefix/;        
    if ($ontology->{TERMS_SET}->contains_id($id)){
        	push @out, $record;
        	#$count++; 
    }
}
#print "added $count annotations out of $.\n"; 
print @out;

#my $end = time;

