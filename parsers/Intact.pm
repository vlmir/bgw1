#! /usr/bin/perl
package parsers::Intact;

use strict;
use warnings;
use Carp;

# from: https://perlmaven.com/json
use 5.010; # needed even though perl 5.26 installed
# to install Cpanel::JSON::XS gcc and make are required
# then: cpan Cpanel::JSON::XS
use Cpanel::JSON::XS qw(encode_json decode_json);

my $verbose = 1;
if ( $verbose ) {
	use Data::Dumper;
	$Carp::Verbose = 1;
}

use auxmod::SharedSubs qw( 
open_read
open_write
);

# sorce names as defined in the data (there are other sources as well)
my $ppiSrc = 'intact'; # taking from the data
my $pblSrc = 'pubmed'; # taking from the data
my $tlpSrc = 'uniprotkb'; # taking from the data

## keys used in hashes
my $irnk = 'Interactions';
my $tlpk = 'Participants';
my $exrlk = 'ExperimentalRoles';
my $pblk = 'PubIDs';
my $irnmk = 'interactionName';
my $irdek = 'interactionFullName';
my $irtpk = 'InteractionTypes';
my $mthk = 'DetectionMethods';
my $logk = 'log';

my $keydlm = '+';
my @rlskeys = ( 'ppi2tlp', 'tlp2tlp', 'stm2evd' );

## TODO move regex's out of loops !

sub new {
	my $class = shift;
	my $self = {};
	bless ( $self, $class );
	return $self;
}

########################################################################
=head2 parse

 Usage - $intact_parser->parse ( $intact_files, $map )
 Returns - data structure ( hash reference )
 Args -
	 1. [ IntAct data tab file path ( fully qualified )] ( string )
	 2. { UniProtKB accession => UniProtKB id ( strings )} ( hash reference )
	 3. { UniProtKB accession => UniProtKB id ( strings )} ( hash reference ), optional
 Function - parses IntAct data file and optionally filters it by the map

 Input file fields:
        1 ID(s) interactor A
        2 ID(s) interactor B
        3 Alt. ID(s) interactor A
        4 Alt. ID(s) interactor B
        5 Alias(es) interactor A
        6 Alias(es) interactor B
        7 Interaction detection method(s)
        8 Publication 1st author(s)
        9 Publication Identifier(s)
       10 Taxid interactor A
       11 Taxid interactor B
       12 Interaction type(s)
       13 Source database(s)
       14 Interaction identifier(s)
       15 Confidence value(s)
       16 Expansion method(s)
       17 Biological role(s) interactor A
       18 Biological role(s) interactor B
       19 Experimental role(s) interactor A
       20 Experimental role(s) interactor B
       21 Type(s) interactor A
       22 Type(s) interactor B
       23 Xref(s) interactor A
       24 Xref(s) interactor B
       25 Interaction Xref(s)
       26 Annotation(s) interactor A
       27 Annotation(s) interactor B
       28 Interaction annotation(s)
       29 Host organism(s)
       30 Interaction parameter(s)
       31 Creation date
       32 Update date
       33 Checksum(s) interactor A
       34 Checksum(s) interactor B
       35 Interaction Checksum(s)Negative
       36 Feature(s) interactor A
       37 Feature(s) interactor B
       38 Stoichiometry(s) interactor A
       39 Stoichiometry(s) interactor B
       40 Identification method participant A
       41 Identification method participant B

=cut
sub parse {
# ATTN: the values of the 'Pairs' key are NOT full proof due to the 'psi-mi' entries TODO refine
	# field 14: the first ID is always EBI, redundant; EBI IDs occur in other positions, currently in one row
	# fields 1+2: not unique !!
	# TODO split MI ids
	# TODO change the modeling of Experimental roles
	# the map should contain complete proteomes for all the taxa in the project !!
	# if a map provided the output is limited to PPIs
	my $self = shift;
	my (
	$file,
	$map, # { UP AC => 1 } ( optional, should be used normally to exclude extraneous proteins and fragments ! )
	) = @_;
	my $data;
	#~ my %problems;
	
	my $count_accepted =0;
	my $count_rejected =0;
	my $count = 0;
	my $FH = open_read ( $file );
	while ( <$FH> ){
		next if substr ( $_, 0, 1) eq "\n";
		next if substr ( $_, 0, 1) eq "#";
		$count++;
		chomp;
		my @fields = split ( /\t/ );
		
		# Interactions
		# currently the primary ID is always intact;
		# the primary seems sufficient
		my @ppiIds  = split ( /\|/, $fields[13] );
		my ( $ppiPrimDb, $ppiPrimId ) = split /:/, $ppiIds[0]; # the first interaction ID is always intact:EBI
		if ( $fields[35] eq 'true' ) { $data->{$logk}{'Negative'}{$ppiPrimId}++; next } # excluding negative interactions
		
		# particpants IDs
		# Note: if UP AC is available it is always in the first field for both proteins
		# more precisely - it is either  in the first field or both, no need to inspect the second field
		my @aIds = split ( /\|/, $fields[0] );
		my @bIds = split ( /\|/, $fields[1] );

		my ( $aSrc, $aPrimId ) = split /:/, $aIds[0];
		my ( $bSrc, $bPrimId ) = split /:/, $bIds[0];
		# some interactions involve a single protein, e.g. in case of auto-phosphorylation
		if ( ! $bPrimId ) { # '-' value occurs but not in the human dataset, instead A == B
			$data->{$logk}{'NoInteractorB'}{$ppiPrimId}++;
			$bPrimId = $aPrimId;
			$bSrc = $aSrc;
		}
		
		my $mySrc = 'uniprotkb';
		next unless ($aSrc eq $mySrc and $bSrc eq $mySrc);

		my ($aBaseId, $axt) = split /-/, $aPrimId;
		my ($bBaseId, $bxt) = split /-/, $bPrimId;
		# filtering		
		if ( $map ) {
			if ( ! $map->{$aBaseId} ) { $data->{$logk}{'notInMap'}{$aBaseId}++; next; }
			if ( ! $map->{$bBaseId} ) { $data->{$logk}{'notInMap'}{$bBaseId}++; next; }
		} # end if map

		my $pairid = $aPrimId lt $bPrimId ?
			$aPrimId . $keydlm . $bPrimId : $bPrimId . $keydlm . $aPrimId;
		my $mykey = 'up' . $keydlm . 'up';
		$data->{'Pairs'}{$mykey}{$pairid}{$ppiPrimDb}{$ppiPrimId}++;
		$data->{$irnk}{$ppiPrimDb}{$ppiPrimId}{'Pairs'}{$mykey}{$pairid}++;


		my @subfields;
		# Interacton types
		# multiple pipe separated values
		# currently all interacions in IntAct have just a single interaction type
		# nevertheless assuming multiple types
		my @ppiTypes = split ( /\|/, $fields[11] ); # e.g. psi-mi:"MI:0915"(physical association)
		if ( $ppiTypes[0] ne '-' ) { # this conditional is unnecessary - the first 15 fields are mandatory
			foreach ( @ppiTypes ) {
				$_ =~ /(\S+?):"(\S+?)"\((.+?)\)/; # TODO use split on ':', '"' instead?
				if ( $2 ) {
					$data->{$irnk}{$ppiPrimDb}{$ppiPrimId}{$irtpk}{$2} = $3;
				}
				else {
					$data->{$logk}{'badTypeId'}{$ppiPrimId}++;
				}
			}
		}else{$data->{$logk}{'noTypeId'}{$ppiPrimId}++;}
		
		# methods
		# currently all interacions in IntAct have just a single detection method
		# nevertheless assuming multiple methods
		my @methods = split ( /\|/, $fields[6] ); # e.g. psi-mi:"MI:0071"(molecular sieving)
		if ( $methods[0] ne '-' ) { # this conditional is unnecessary - the first 15 fields are mandatory
			foreach ( @methods ) {
				$_ =~ /(\S+?):"(\S+?)"\((.+?)\)/;
				if ( $2 ) {
					$data->{$irnk}{$ppiPrimDb}{$ppiPrimId}{'DetectionMethods'}{$2} = $3;
				}
				else {
					$data->{$logk}{'badMtdId'}{$ppiPrimId}++;
				}
			}
		}else{$data->{$logk}{'noMtdId'}{$ppiPrimId}++;}
		
		# PubMed ids
		# all interacions in IntAct have a publication ref
		# ATTN: numerous rows contain in column 9 junk like psi-mi:"MI:1234" !!!
		@subfields = split ( /\|/, $fields[8] );
		if ( $subfields[0] ne '-' ) { # this conditional is unnecessary - the first 15 fields are mandatory
			# PubMed ref is pressent in any record not necessarily in the first field
			foreach ( @subfields ) {
				my ( $key, $val ) = split /:/;
				next unless $key eq 'pubmed'; # the rest is useless or even erroneous lile psi-mi ids !!
				$data->{$irnk}{$ppiPrimDb}{$ppiPrimId}{$pblk}{$key}{$val}++;
				$data->{'Pairs'}{$mykey}{$pairid}{$key}{$val}++;
			}
		}else{$data->{$logk}{'noPblId'}{$ppiPrimId}++;}
		
		# Confidence
		@subfields = split ( /\|/, $fields[14] );
		if ( $subfields[0] ne '-' ) {
			foreach my $score (@subfields) {
				my ($key, $val) = split /:/, $score;
				next unless $key eq 'intact-miscore'; # to avoid 'author-score'
				$data->{$irnk}{$ppiPrimDb}{$ppiPrimId}{Scores}{$key}{$val}++;
				$data->{'Pairs'}{$mykey}{$pairid}{$key}{$val}++; # sic: multiple values possible
			}
		}
		## Expansion methods
		# currently for less than a half rows
		@subfields = split ( /\|/, $fields[15] );
		if ( $subfields[0] ne '-' ) {
			foreach my $method (@subfields) {
				my ($key, $val) = split /"/, $method; # $type: 'psi-mi' if any
				($key) = split /:/, $key; # no expansion: key: '-' value: '' (empty string)
			}
		}

############################# Participants ####################################
		# Experimental roles, optional - currently not used:
		# TODO change the modeling
		my @aExpRoles  = split ( /\|/, $fields[18] );
		my @bExpRoles  = split ( /\|/, $fields[19] );
		if ( $aExpRoles[0] ne '-' ) { # necessary indeed
			foreach ( @aExpRoles ) {
				$_ =~ /(\S+?):"(\S+?)"\((.+?)\)/;
				$data->{$irnk}{$ppiPrimDb}{$ppiPrimId}{$tlpk}{$aSrc}{$aBaseId}++;
				$data->{$tlpk}{$aSrc}{$aBaseId}{$ppiPrimDb}{$ppiPrimId}{$exrlk}{$2} = $3;
			}
		}else{$data->{$logk}{'noExpRoleId'}{$ppiPrimId}++;}
		if ( $bExpRoles[0] ne '-' ) {
			foreach ( @bExpRoles ) {
				$_ =~ /(\S+?):"(\S+?)"\((.+?)\)/;
				$data->{$irnk}{$ppiPrimDb}{$ppiPrimId}{$tlpk}{$bSrc}{$bBaseId}++;
				$data->{$tlpk}{$bSrc}{$bBaseId}{$ppiPrimDb}{$ppiPrimId}{$exrlk}{$2} = $3;
			}
		}else{$data->{$logk}{'noExpRole'}{$ppiPrimId}++;}	
		$count_accepted++;
	}# end of while $FH
	close $FH;
	$count_rejected = $count - $count_accepted;
# 	print "Entries: accepted - $count_accepted, rejected - $count_rejected, total - $count;\n" if $verbose;
	if ($data->{'Interactions'}) {
	# to make file re-naming independent of extension length:
	my @chunks = split /\./, $file;
	pop @chunks;
	my $path = join '.', @chunks;
	$file = $path . '.json';
	my $var = encode_json $data;
	my $OUT = open_write ( $file );
	print $OUT $var;
	return $data;
	} else {
	carp "No data to return\n";
	return 0;
	}
}

1
