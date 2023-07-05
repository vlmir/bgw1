#!/usr/local/bin/perl
# $Id: get_terms_and_synonyms.pl 2010-12-01 erick.antezana $
#
# Script  : get_terms_and_synonyms.pl
#
# Purpose : Find all the terms and synonyms in a given ontology.
#
# Usage   : get_terms_and_synonyms.pl my_ontology.obo > term_and_its_synonyms.txt
#
# License : Copyright (C) 2006-2011 by Erick Antezana. All rights reserved.
#           This program is free software; you can redistribute it and/or
#           modify it under the same terms as Perl itself.
#
# Contact : Erick Antezana <erick.antezana -@- gmail.com>
#
###############################################################################

use Carp;
use strict;
use warnings;

BEGIN{
        #~ unshift @INC, "/norstore/user/mironov/workspace/onto-perl/ONTO-PERL-1.37/lib";
        #~ unshift @INC, "/norstore/user/erick/SEM-ALIGN/Date-Manip-6.24/lib";
        unshift @INC, '/norstore/project/ssb/workspace/onto-perl/lib';
}


use OBO::Parser::OBOParser;

my $my_parser = OBO::Parser::OBOParser->new();
my $ontology = $my_parser->work(shift(@ARGV)); # the only argument

my @sorted_terms = map { $_->[0] }           # restore original values
                                sort { $a->[1] cmp $b->[1] } # sort
                                map  { [$_, $_->id()] }      # transform: value, sortkey
                                @{$ontology->get_terms("UniProtKB:[A-Z0-9]{5,7}\$")}; # get proteins!
					
foreach my $term (@sorted_terms) {
	print "\n", $term->id();
	
	my @rels_by_s = @{$ontology->get_relationships_by_source_term($term, 'member_of')};

	foreach my $pwr (@rels_by_s) {
		print "\t", $pwr->head()->id();
	}
	
#	my @sorted_syns = map { $_->[0] }                 # restore original values
#				sort { $a->[1] cmp $b->[1] }          # sort
#				map  { [$_, lc($_->def()->text())] }  # transform: value, sortkey
#				$term->synonym_set();
}
exit 0;

__END__

=head1 NAME

get_terms_and_synonyms.pl - Find all the terms and synonyms in a given ontology.

=head1 USAGE

get_terms_and_synonyms.pl my_ontology.obo > term_and_its_synonyms.txt

=head1 DESCRIPTION

This script retrieves all the terms and its synonyms in an OBO-formatted ontology. 

=head1 AUTHOR

Erick Antezana, E<lt>erick.antezana -@- gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2011 by Erick Antezana

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
