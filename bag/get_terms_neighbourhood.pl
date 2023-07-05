#!/usr/local/bin/perl
# $Id: get_terms_neighbourhood.pl 2011-08-03 erick.antezana $
#
# Script  : get_terms_neighbourhood.pl
#
# Purpose : Find the neighbourhood of all the terms in a given ontology.
#
# Usage   : get_terms_neighbourhood.pl my_ontology.obo > terms.txt
#
# License : Copyright (C) 2006-2011 by Erick Antezana. All rights reserved.
#           This program is free software; you can redistribute it and/or
#           modify it under the same terms as Perl itself.
#
# Contact : Erick Antezana <erick.antezana -@- gmail.com>
#
########################################################################

BEGIN{
	unshift @INC, '/norstore/project/ssb/workspace/onto-perl/lib';
}
use Carp;
use strict;
use warnings;
$Carp::Verbose = 1;
use IO::Handle;
use OBO::Parser::OBOParser;

my ( 
$ontoFile, # input ontology path
$regex # regular expression for filtering term IDs, e.g. 'UniProtKB:[A-Z0-9]{5,7}' 
) = @ARGV;

my $date;
my ( $project ) = $ontoFile =~ /(\S+)\.obo/;
open my $log_fh, '>', $project.'.log' || croak "Cannot open file $project.log: $!";
$log_fh->autoflush();
			
$date = `date`;
print $log_fh "1. ONTOLOGY IS BEING PARSED: $date";
my $my_parser = OBO::Parser::OBOParser->new();
my $ontology  = $my_parser->work($ontoFile );

########################################################################
#
# Get a sorted array of the terms (proteins)
#
########################################################################
$date = `date`;
print $log_fh "2. TERMS ARE BEING SORTED: $date";
my @sorted_terms = map { $_->[0] }           # restore original values
				sort { $a->[1] cmp $b->[1] } # sort
				map  { [$_, $_->id()] }      # transform: value, sortkey
				@{$ontology->get_terms("$regex\$")};

########################################################################
#
# Get the local neighbourhood for each term
#
# feature = relationship_id + term_id
#
########################################################################
$date = `date`;
print $log_fh "3. TERMS ARE BEING EXTRACTED: $date";
my %matrix;
foreach my $t (@sorted_terms) {	
	my @rels = @{$ontology->get_relationships_by_source_term($t)};
	foreach my $rel (@rels) {
		# feature ID: 'property_object'
		my $r_type  = $rel->type();			
		my $head_id = $rel->head()->id();
		my $key     = $r_type.'_'.$head_id;		
		$matrix{$key}{$t->id()} = 1;
	}
	@rels = @{$ontology->get_relationships_by_target_term($t)};
	foreach my $rel (@rels) {
		# feature ID: 'property_subject'
		my $r_type  = $rel->type();	
		my $tail_id = $rel->tail()->id();
		my $key     = $r_type.'_'.$tail_id;
		$matrix{$key}{$t->id()} = 1;
	}
}

########################################################################
#
# export the features into a fasta-like file
#
########################################################################

$date = `date`;
print $log_fh "4. KEYS ARE BEING SORTED: $date";
my @sorted_keys = map { $_->[0] }            # restore original values
				sort { $a->[1] cmp $b->[1] } # sort
				map  { [$_, $_] }            # transform: value, sortkey
				keys %matrix;                # get features!

$date = `date`;
print $log_fh "5. PROFILES ARE BEING PRINTED: $date";			
open my $profiles_fh, '>', $project.'.fasta' || croak "Cannot open file $project.fasta: $!";
foreach my $t (@sorted_terms) {	
	my $t_id      = $t->id();
	( my $local_id ) = $t_id =~ /\w+:(\S+)/ or carp "Skipping term $t_id: malformed ID";
	next unless $local_id;	
	print $profiles_fh ">", $local_id, "\n";
	foreach my $f (@sorted_keys) {
		print $profiles_fh exists $matrix{$f}{$t_id} ? '1' : '0';
	}
	print $profiles_fh "\n";
}
#~ print $profiles_fh "\n";
close $profiles_fh;

$date = `date`;
print $log_fh "6. FEATURES ARE BEING PRINTED: $date";
open my $features_fh, '>', $project.'.list' || croak "Cannot open file $project.list: $!";
foreach my $f (@sorted_keys) {
	print $features_fh $f, "\n";
}
close $features_fh;
$date = `date`;
print $log_fh "7. END: $date";
exit 0;

__END__

=head1 NAME

get_terms_neighbourhood.pl - Find the neighbourhood of all the terms in a given ontology.

=head1 DESCRIPTION

This script retrieves the neighbourhood of all the terms in a given OBO-formatted ontology.

=head1 AUTHOR

Erick Antezana, E<lt>erick.antezana -@- gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2011 by Erick Antezana

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
