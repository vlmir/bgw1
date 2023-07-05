#!/usr/bin/perl
package parsers::Ortho;

BEGIN {
	#~ unshift @INC, '/norstore/user/mironov/workspace/ONTO-PERL-1.34/lib';
	#~ unshift @INC, '/norstore/project/ssb/workspace/onto-perl/lib';
}
use Carp;
use strict;
use warnings;


my $verbose = 1;
if ( $verbose ) {
	use Data::Dumper;
	$Carp::Verbose = 1;
}

use auxmod::SharedSubs qw( 
char_http
__date
test_prns
set_props
add_new_term
retrieve_term
create_triple
open_read
open_write

);
use auxmod::SharedVars qw( 
%nss
%props
%prns
%uris
);

my $PRTNS = $nss{'ptn'};
my $ptnns = lc $PRTNS;

########################## new() ###############################################
sub new {
 my $class = $_[0];
 my $self = {};
 bless ( $self, $class );
 return $self;
}

########################### parse_abc ##########################################
sub parse_abc {
	my (
		$self,
		$in_file_path,
# 		$type, # orl2orl | prl2prl, for orthologs and paralogs respectively  # TODO is it noecessary ? not used in ortho2onto
		$map, # { UP AC => 1 } ( optional, to exclude extraneous proteins )
	) = @_;
	my $data;
	my $count_accepted =0;
	my $count_rejected =0;
	my $count = 0;
	
	my $FH = open_read ( $in_file_path );
	while ( <$FH> ){
		next if substr ( $_, 0, 1) eq "\n";
		next if substr ( $_, 0, 1) eq "#";
		$count++;
		chomp;
		my @fields = split ( /\t/ ); #print Dumper ( \@fields );
		my ( $txidA, $upacA ) = split /\|/, $fields[0];
		my ( $txidB, $upacB ) = split /\|/, $fields[1];
		# filtering - both proteins must be in the map
		if ( $map ) {
			next unless $map->{$upacA} && $map->{$upacB}; # the same with 'and'
		}
# 		$data->{$PRTNS}{$upacA}{$PRTNS}{$upacB} = $type;
		$data->{$PRTNS}{$upacA}{$PRTNS}{$upacB}++;
# 		$data->{$PRTNS}{$upacB}{$PRTNS}{$upacA} = $type;
		$data->{$PRTNS}{$upacB}{$PRTNS}{$upacA}++;
		$count_accepted++;
	}
	$count_rejected = $count - $count_accepted;
	print "Entries: accepted - $count_accepted, rejected - $count_rejected, total - $count;\n" if $verbose;
	$data ? return $data : carp "No data to return\n";
}

############################# ortho2onto #######################################
sub ortho2onto {
	my (
		$self,
		$onto,
		$data, # ouput of parse_abc
		$key, # orl2orl | prl2prl, for orthologs and paralogs respectively
		$map, # the map of core proteins, ouput of goa2onto()
	 ) = @_;
	#------------------------- PREAMBULE -----------------------------------------
	## setting rels in the onto 
	my @keys = ( $key );
	my $tpdefs = set_props ( $onto, \%props, \@keys );
	# testing the parent terms in the ontology
	my $parents = test_prns ( $onto, \%prns );
	my @parents = ( $parents->{'ptn'} ); # a single element array of term objects
	# hashes to collect terms
	my %proteins; # {protein term id => OBO::Core::Term object}
	my %new_proteins; # {UP_AC =>  1}
	my $fs = ':';
	
	#-----------------------------------------------------------------------------
	my $rltp = $tpdefs->{$key};
	foreach my $upacA ( keys %{$data->{$PRTNS}} ) {
		my @upacBs = keys %{$data->{$PRTNS}{$upacA}{$PRTNS}};
		my $found = 0;
		map { $found++ if $map->{$_};  } $upacA, @upacBs;
		next unless $found;
		# loading the proteins in the onto and the hashes:
		foreach ( $upacA, @upacBs ) {
			my $ptnid = $PRTNS.$fs.$_;
			my $ptn = retrieve_term ( $onto, $ptnid, \%proteins );
			if ( ! $ptn ) {
				$ptn = add_new_term ( $onto, $ptnid, \@parents, \%proteins );
				$new_proteins{$_}++;
			}
		} # end of foreach upac
		# now all the proteins in questions are in the onto and the hashes
		# creating one way relations:
		map { create_triple ( $onto, $proteins{$PRTNS.$fs.$upacA}, $rltp, $proteins{$PRTNS.$fs.$_} ) } @upacBs;
	} # end of foreach upacA
	# now all the relations should be two way
	( keys %new_proteins ) > 0 ? return \%new_proteins : carp "Nothing to return";
}

################################################################################

1;
