
package parsers::Intact;

use strict;
use warnings;
use Carp;

# currently not used
#~ use Config;
#~ use threads;
#~ use threads::shared;
#~ $Config{useithreads} or croak ('Recompile Perl with threads to run this program.');
# use XML::LibXML qw(:threads_shared);

my $verbose = 1;
if ( $verbose ) {
	use Data::Dumper;
	$Carp::Verbose = 1;
}

use OBO::Core::Term;
use auxmod::SharedSubs qw( 
char_http
__date
test_prns
add_new_term
retrieve_term
create_triple
set_props
open_read
open_write
write_ttl_header
write_ttl_preambule
write_ttl_properties

);
use auxmod::SharedVars qw( 
%nss
%props
%prns
%uris
);

my $PPINS = $nss{'ppi'};
my $PRTNS = $nss{'ptn'};
my $TXNNS = $nss{'txn'};
my $PMNS = $nss{'pm'}; # PubMed
my $SSB = $nss{'ssb'};

my $ppins = lc $PPINS;
my $ptnns = lc $PRTNS;
my $pmns = lc $PMNS;
my $ssb = lc ($SSB);

# sorce names as defined in the data (there are other sources as well)
my $ppiSrc = 'intact'; # taking from the data
my $pblSrc = 'pubmed'; # taking from the data
my $ptnSrc = 'uniprotkb'; # taking from the data

## keys used in hashes
my $irnk = 'Interactions';
my $ptnk = 'Participants';
my $exrlk = 'ExperimentalRoles';
my $pblk = 'PubIDs';
my $irnmk = 'interactionName';
my $irdek = 'interactionFullName';
my $irtpk = 'InteractionTypes';
my $mthk = 'DetectionMethods';
my $logk = 'log';

my @rlskeys = ( 'ppi2ptn', 'ptn2ptn', 'stm2evd' );

## TODO move regex's out of loops !

sub new {
	my $class = shift;
	my $self = {};
	bless ( $self, $class );
	return $self;
}

=head2 parse_psimi

 Usage - $intact_parser->parse_psimi ( $intact_files, $map )
 Returns - data structure ( hash reference )
 Args -
	 1. [ IntAct data file paths ( fully qualified )] ( array reference )
	 2. { UniProtKB accession => UniProtKB id ( strings )} ( hash reference )
	 3. { UniProtKB accession => UniProtKB id ( strings )} ( hash reference ), optional
 Function - parses IntAct data file and optionally filters it by the map

=cut
########################################################################
=head2 parse_tab

 Usage - $intact_parser->parse_tab ( $intact_files, $map )
 Returns - data structure ( hash reference )
 Args -
	 1. [ IntAct data tab file path ( fully qualified )] ( string )
	 2. { UniProtKB accession => UniProtKB id ( strings )} ( hash reference )
	 3. { UniProtKB accession => UniProtKB id ( strings )} ( hash reference ), optional
 Function - parses IntAct data file and optionally filters it by the map

=cut

#        1 ID(s) interactor A
#        2 ID(s) interactor B
#        3 Alt. ID(s) interactor A
#        4 Alt. ID(s) interactor B
#        5 Alias(es) interactor A
#        6 Alias(es) interactor B
#        7 Interaction detection method(s)
#        8 Publication 1st author(s)
#        9 Publication Identifier(s)
#       10 Taxid interactor A
#       11 Taxid interactor B
#       12 Interaction type(s)
#       13 Source database(s)
#       14 Interaction identifier(s)
#       15 Confidence value(s)
#       16 Expansion method(s)
#       17 Biological role(s) interactor A
#       18 Biological role(s) interactor B
#       19 Experimental role(s) interactor A
#       20 Experimental role(s) interactor B
#       21 Type(s) interactor A
#       22 Type(s) interactor B
#       23 Xref(s) interactor A
#       24 Xref(s) interactor B
#       25 Interaction Xref(s)
#       26 Annotation(s) interactor A
#       27 Annotation(s) interactor B
#       28 Interaction annotation(s)
#       29 Host organism(s)
#       30 Interaction parameter(s)
#       31 Creation date
#       32 Update date
#       33 Checksum(s) interactor A
#       34 Checksum(s) interactor B
#       35 Interaction Checksum(s)Negative
#       36 Feature(s) interactor A
#       37 Feature(s) interactor B
#       38 Stoichiometry(s) interactor A
#       39 Stoichiometry(s) interactor B
#       40 Identification method participant A
#       41 Identification method participant B

sub parse_tab {
	# each pair of proteins is present in both orientation - the counts are at least 2
	# TODO split MI ids
	# TODO change the modeling of Experimental roles
	# the map should contain complete proteomes for all the taxa in the project !!
	# if a map provided the output is limited to PPIs
	my $self = shift;
	my (
	$in_file_path,
	$map, # { UP AC => 1 } ( optional, should be used normally to exclude extraneous proteins and fragments ! )
	) = @_;
	my $data;
	#~ my %problems;
	
	my $count_accepted =0;
	my $count_rejected =0;
	my $count = 0;
	my $FH = open_read ( $in_file_path );
	while ( <$FH> ){
		next if substr ( $_, 0, 1) eq "\n";
		next if substr ( $_, 0, 1) eq "#";
		$count++;
		chomp;
		my @fields = split ( /\t/ );
		
		# Interactions
		# currently the primary ID is always intact; the secondory one either intact or imex (publication ref?)
		# the primary seem sufficient
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
		if ( ! $bPrimId ) { 
			$data->{$logk}{'NoInteractorB'}{$ppiPrimId}++; $bPrimId = $aPrimId;
		}
		

		# filtering		
		if ( $map ) {
			if ( ! $map->{$aPrimId} ) { $data->{$logk}{'notInMap'}{$aPrimId}++; next; }
			if ( ! $map->{$bPrimId} ) { $data->{$logk}{'notInMap'}{$bPrimId}++; next; }
		} # end if map

		
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
		my @pblids = split ( /\|/, $fields[8] );
		if ( $pblids[0] ne '-' ) { # this conditional is unnecessary - the first 15 fields are mandatory
			# PubMed ref is pressent in any record not necessarily in the first field
			foreach ( @pblids ) {
				my ( $src, $id ) = split /:/;
				$data->{$irnk}{$ppiPrimDb}{$ppiPrimId}{$pblk}{$src}{$id}++;
			}
		}else{$data->{$logk}{'noPblId'}{$ppiPrimId}++;}
		
################################## Pairs ######################################
		
		# Confidence
		@subfields = split ( /\|/, $fields[14] );
		if ( $subfields[0] ne '-' ) {
			my $scores;
			foreach my $score (@subfields) {
				my ($type, $value) = split /:/, $score;
				$scores->{$type}{$value}++;
				$data->{'Pairs'}{$aSrc}{$aPrimId}{$bSrc}{$bPrimId}{$type}{$value}++;
				$data->{'Pairs'}{$bSrc}{$bPrimId}{$aSrc}{$aPrimId}{$type}{$value}++;
			}
		}
		## Expansion methods
		@subfields = split ( /\|/, $fields[15] );
		if ( $subfields[0] ne '-' ) {
			foreach my $method (@subfields) {
				my ($type, $value) = split /"/, $method;
				($type) = split /:/, $type; # no expansion: key: '-' value: '' (empty string)
				$data->{'Pairs'}{$aSrc}{$aPrimId}{$bSrc}{$bPrimId}{$type}{$value}++;
				$data->{'Pairs'}{$bSrc}{$bPrimId}{$aSrc}{$aPrimId}{$type}{$value}++;
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
				$data->{$irnk}{$ppiPrimDb}{$ppiPrimId}{$ptnk}{$aSrc}{$aPrimId}++;
				$data->{$ptnk}{$aSrc}{$aPrimId}{$ppiPrimDb}{$ppiPrimId}{$exrlk}{$2} = $3;
			}
		}else{$data->{$logk}{'noExpRoleId'}{$ppiPrimId}++;}
		if ( $bExpRoles[0] ne '-' ) {
			foreach ( @bExpRoles ) {
				$_ =~ /(\S+?):"(\S+?)"\((.+?)\)/;
				$data->{$irnk}{$ppiPrimDb}{$ppiPrimId}{$ptnk}{$bSrc}{$bPrimId}++;
				$data->{$ptnk}{$bSrc}{$bPrimId}{$ppiPrimDb}{$ppiPrimId}{$exrlk}{$2} = $3;
			}
		}else{$data->{$logk}{'noExpRole'}{$ppiPrimId}++;}	
		$count_accepted++;
	}# end of while $FH
	close $FH;
	$count_rejected = $count - $count_accepted;
# 	print "Entries: accepted - $count_accepted, rejected - $count_rejected, total - $count;\n" if $verbose;
	# TODO move the counting below to Intact.pl
	foreach my $primk ( sort keys %{$data} ) {
# 		map { my $count = keys %{$data->{$primk}{$_}}; print "$primk:$_ $count\n"; } sort keys %{$data->{$primk}};
	}
	$data->{'Interactions'} ? return $data : carp "No data to return\n";

}


=head2 work

 Usage - $intact_parser->work ( $ontology, $data, $parent_protein_name )
 Returns - { NCBI ID => { UP AC => OBO::Core::Term object }} ( data structure with all the proteins in the interactions )
 Args -
	1. OBO::Core::Ontology object,
	2. data structure from parse ( )
	#~ 3. parent term name for proteins ( string ) # to link new proteins to, e.g. 'cell cycle protein'
 Function - adds to the input ontology OBO::Core::Term objects along with appropriate relations for interactions and proteins from IntAct data

=cut
# TODO double check the output ontology
sub intact2onto {
	# TODO add MI methods to APOs ??
	# TODO experimental roles for participants
	# TODO find a relation type to link experimental methods and roles
	# this functions expects all the filtering done beforehand !!!
	my (
		$self,
		$onto,
		$data, # ouput of parse()
		$map, # the map of core proteins, ouput of goa2onto()
	 ) = @_;

	#------------------------- PREAMBULE -----------------------------------------
	# setting rels in the onto 
	
	my $tpdefs = set_props ( $onto, \%props, \@rlskeys );
		
	# testing the parent terms in the ontology
	my $parents = test_prns ( $onto, \%prns );
	my @parents = ( $parents->{'ptn'} );
	# hashes to collect terms
	my %mi_terms; # {MI ID => OBO::Core::Term object}
	my %proteins; # {protein term id => OBO::Core::Term object}
	my %new_proteins; # {UP_AC =>  1}
	my $fs = ':';
	my $onto_name = $onto-> name() ;  croak 'No onto name' unless $onto_name;
	#-----------------------------------------------------------------------------
	# TODO double check the logics - multiple lines with the same ID, multiple IDs for many PPIs !!!
	foreach my $ppi_id ( keys %{$data->{$irnk}{$ppiSrc}} ) {
		my $ppi = $data->{$irnk}{$ppiSrc}{$ppi_id};
		# Participants
		my @upacs = keys %{$ppi->{$ptnk}{$ptnSrc}};
		
		if ( ! @upacs ) {
			carp 'Interacton '.$ppi_id.' has no participants';
			next;
		}
		# filtering by the map, at least one of the participants must be in the map
		my $found;
		map { $found++ if $map->{$_} } @upacs;
		next unless $found;
		# Interaction Types
		my @ppi_type_ids = keys %{$ppi->{$irtpk}};
		if ( ! @ppi_type_ids ) {
			carp "Interacton: $ppi_id has no interaction types";
			next;
		}
		
		# detection methods, normally single but not necessarily
		my @method_ids = keys %{$ppi->{'DetectionMethods'}};
		if ( @method_ids == 0 ) {
			carp 'Interacton '.$ppi_id.' has no detecton methods';
			next;
		}
		# PUblications, only PubMed
		my @pubmed_ids = keys %{$ppi->{$pblk}{$pblSrc}};
		if ( ! @pubmed_ids ) {
			carp 'Interacton '.$ppi_id.' has no PubMed IDs'; # in reality should not happen
		}
		
		# Note: interaction types and methods are used only for definitions
		# Interaction type names
		my @type_names;
		foreach my $ppi_type_id ( @ppi_type_ids ) {
			my $mi_term = retrieve_term ( $onto, $ppi_type_id, \%mi_terms );
			next unless $mi_term;
			push @type_names, $mi_term->name ( );
		}
		# method names
		# Note: the method branch not yet included in the seed.obo
		my @method_names;
		foreach my $method_id ( @method_ids ) {
			my $mi_term = retrieve_term ( $onto, $method_id, \%mi_terms );
			next unless $mi_term; # bad test - always true, TODO correct for the future 
			push @method_names, $mi_term->name ( );
		}
		# name 
		my $ppi_name = 'Protein-protein interaction '.$ppi_id;
		# definition
		my $def;
		$def = join ', ', @type_names;
		$def .= ' of proteins ';
		$def .= join ', ', @upacs;
		$def .= ' detected by ' if @method_names;
		$def .= join ', ', @method_names;
		$def .= '.';
		
		# New interaction terms
		# Note: multiple PPI type IDs are possible for a given interaction
		my @parents; # OBO::Core::Term
		map { push @parents, $mi_terms{$_}; } @ppi_type_ids;
		my $new_ppi = add_new_term ( $onto, $PPINS.$fs.$ppi_id, \@parents );
		$new_ppi->name ( $ppi_name );
		$new_ppi->def_as_string ( $def, "[$onto_name:team]" ); croak "No onto name locally" unless $onto_name;
		map { $new_ppi->xref_set_as_string ( '['.$PMNS.$fs.$_.']' ) } @pubmed_ids;
		
		# protein terms
# 		foreach my $up_ac ( @upacs ) {
		@parents = ( $parents->{'ptn'} ); # OBO::Core::Term
		
		my $rltp = $tpdefs->{'ppi2ptn'};
		foreach ( @upacs ) {
			my $ptnid = $PRTNS.$fs.$_;
			my $ptn = retrieve_term ( $onto, $ptnid, \%proteins );
			if ( ! $ptn ) {
				$ptn = add_new_term ( $onto, $ptnid, \@parents, \%proteins );
				$new_proteins{$_}++;
			}
			$onto = create_triple ( $onto, $new_ppi, $rltp, $ptn ); # that's how it should be !
		} # end of foreach protein
	} # end of foreach ppi
( keys %new_proteins ) > 0 ? return \%new_proteins : carp "Nothing to return: $!";
}



sub intact2ttl {
	# expects all the necessary filtering done before
	# generates a ttl file for IntAct data
	my (
	$self,
	$data, # output from parse_tab()
	$ttl_file,
	) = @_;
	croak "Not enough arguments!" if ( @_ < 3 );

	my $uris = \%uris;
	my $props = \%props;
	my $fs = '_';
	my $buffer = '';
	my $OUT = open_write ( $ttl_file );
	my $s = " ;\n\t";
	my $sp = " ,\n\t\t";
	
	### Preambule of RDF file ###
	$buffer = write_ttl_preambule ( $uris,  );
	### Properties ###
	$buffer .= write_ttl_header ( 'Properties' );
	$buffer .= write_ttl_properties ( $uris, $props, \@rlskeys );
	print $OUT $buffer; $buffer = "";

	### Classes ###
	$buffer = write_ttl_header ( 'Classes' );
	print $OUT $buffer; $buffer = "";
	
	# parent term
	# currently: http://purl.obolibrary.org/obo/MI_0000
	my $ppi_prn = $prns{'ppi'}[0];
	$ppi_prn =~ tr/:/_/;
	my $irns = $data->{$irnk}{$ppiSrc};
	my ( $NS, $id );
	foreach my $irnid ( sort keys %{$irns} ) {
		my $irn = $irns->{$irnid};
		my ( $buff, $first );
		$buff .=  "\n### $uris->{'intact'}$irnid ###\n\n";
		$buff .= "$ppins:$irnid rdfs:subClassOf rdfs:Class";
		$buff .= $s."rdfs:subClassOf obo:$ppi_prn";
		# Interaction type
		my @irtps;
		foreach ( sort keys %{$irn->{$irtpk}} ) { $_ =~tr/:/_/; push @irtps, $_};
		$first = shift @irtps;
		$buff .= $s."rdfs:subClassOf obo:$first";
		map {  $buff .= $sp."obo:$_" } @irtps; # TODO check
		# Note: the modeling below is according to the modeling in MI - interaction type part_of molecular interaction but is rather cryptic
		#~ map { $_ =~tr/:/_/; $buff .= "\t\t<sio:$rls{'mi2itp'} rdf:resource=\"&obo;$_\"/>\n"; } sort keys %{$irtps};		
		
		## participants
		my @ptns = sort keys %{$irn->{$ptnk}{$ptnSrc}};
		$first = shift @ptns;
		($NS, $id ) = @{$props{'ppi2ptn'}};
		$buff .= $s."sio:$NS$fs$id $ptnns:$first";
		map { $buff .= $sp."$ptnns:$_" } @ptns;
		
		# Detection method	
		my @mths;
		foreach ( sort keys %{$irn->{$mthk}} ) { $_ =~tr/:/_/; push @mths, $_ };
		$first = shift @mths;
		$buff .= $s."rdfs:isDefinedBy obo:$first";
		map { $buff .= $sp."obo:$_" } @mths;
		
		# Experimental role
		# TODO implement
		#~ my $role = $data->{$ptnk}{$ptnSrc}{$bPrimId}{$ppiSrc}{$ppiPrimId}{$exrlk}{$2};
		
		# PubMed (many entries have as well 'imex' as xref, but this is not a publication)
		my @pbls = sort keys %{$irn->{$pblk}{$pblSrc}}; # PubMed ref provided for every entry in IntAct
		$first = shift @pbls;
		if ( $first ) {
			($NS, $id ) = @{$props{'stm2evd'}};
			$buff .= $s."sio:$NS$fs$id pubmed:$first";
			# $buff .= $s."skos:relatedMatch pubmed:$first";
			map { $buff .= $sp."sio:$NS$fs$id pubmed:$_"; } @pbls;
	 		## the tab file has no interaction names
			$buff .= $s."skos:prefLabel \"$PPINS $irnid protein-protein interaction\"";
			print $OUT "$buff .\n";
		} else {
			carp "irnid:$irnid: no pubmed refs";
		}
	}

	### Statements ###
	$buffer = write_ttl_header ( 'Instances' );
	print $OUT "\n$buffer\n";

	my $rltp = $props{ptn2ptn}; # ref to an array
	my $relid = $rltp->[0].$fs.$rltp->[1];
	my $buff_pairs = '';
	my $ptns = $data->{Pairs}{uniprotkb};
	foreach my $aupac ( sort keys %{$ptns} ) {
		my $bptns = $ptns->{$aupac}{uniprotkb};
		foreach my $bupac ( sort keys %{$bptns} ) {
			$buff_pairs .= "uniprot:$aupac obo:$relid uniprot:$bupac .\n";
			my ( $buffer, $first );
			my $stmid = $aupac.'-'.$bupac;
			$buffer .= "ssb:$stmid a rdf:Statement"; # TODO ssb -> bgw
			$buffer .= $s."rdf:subject uniprot:$aupac";
			$buffer .= $s."rdf:predicate obo:$relid";
			$buffer .= $s."rdf:object uniprot:$bupac";
			my @scores = sort keys %{$bptns->{$bupac}{'intact-miscore'}};
			$first = pop @scores; # only the max values used
			print "$stmid: scores:@scores first:$first\n" unless @scores == 0;
			$buffer .= $s."rdfs:label $first";
			print $OUT "$buffer .\n";
		}
	}

	$buffer = write_ttl_header ( 'Pairs' );
	print $OUT "\n$buffer\n";
	print $OUT "\n$buff_pairs\n";
	print $OUT "\n# Generated with $0 ".__date."\n";
	close $OUT;
}
1;
