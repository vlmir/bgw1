package parsers::Goa;

use strict;
use warnings;
use Carp;

use auxmod::SharedSubs qw( 
char_http 
__date 
test_prns 
add_new_term
retrieve_term
open_read
open_write
write_ttl_header
write_ttl_preambule
write_ttl_properties
set_props
create_triple
);
use auxmod::SharedVars qw(
%uris
%nss
%prns
%props
%add_ptntm
);
use OBO::Core::Term;

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};

#--------------------- Global vars ---------------------------------------------
# TODO check the use of all Global vars
my $GOANS = $nss{'goa'};
my $PRTNS = $nss{'ptn'};
my $TXNNS = $nss{'txn'};
my $PMNS = $nss{'pm'}; # PubMed
my $SSB = $nss{'ssb'}; # TODO rename SSB 
my $GONS = 'GO'; # used in all functions but redefined in parse() to the same value

my $goans = lc $GOANS;
my $ptnns = lc $PRTNS;
my $pmns = lc $PMNS;
my $ssb = lc ($SSB);
my $econs = 'eco';

# my %asp2rel = ( # not used 2015-09-08
# 'C' => 'ptn2cc',
# 'F' => 'ptn2mf',
# 'P' => 'ptn2bp',
# );
# 
# my %gotypes = ( # not used 2015-09-08
# 'C' => 'cellularComponent',
# 'F' => 'molecularFunction',
# 'P' => 'biologicalProcess',
# );
my $host = 'hostTaxon'; # used for the interacting taxon
# keys; used as annotation properties
my $aspk = 'aspect';
my $qlfrk = 'qualifier';
my $ecok = 'eco';
my $ifmk = 'isoform';
my $datek = 'date';
my $ansrck = 'source';
# original namespaces in GOA files
my $txnSrc = 'taxon';
my $ptnSrc = 'UniProtKB';

my $logk = 'log';

my @rlskeys = qw ( ptn2bp ptn2cc ptn2mf );
my %tdid2key = (
'involved_in' => 'ptn2bp',
'part_of' => 'ptn2cc',
'enables' => 'ptn2mf'
);
########################################################################

sub new {
	my $class = $_[0];
	my $self = {};
	bless ( $self, $class );
	return $self;
}
#######################################################################
# gpi-version: 1.1
#   name                   required? cardinality   GAF column #  Example content
#   01.DB_Object_ID           required     1             2/17          Q4VCS5-1
#   02.DB_Object_Symbol       required  1             3             AMOT
#   03.DBObject_Name         optional  0 or greater  10            Angiomotin
#   04.DB_Object_Synonym(s)   optional  0 or greater  11            AMOT|KIAA1071
#   05.DB_Object_Type         required  1             12            protein
#   06.Taxon                  required  1             13            taxon:9606
#   07.Parent_Object_ID       optional  0 or 1        -             UniProtKB:Q4VCS5
#   08.DB_Xref(s)             optional  0 or greater  -             WB:WBGene00000035
#   09.Properties             optional  0 or greater  -             db_subset=Swiss-Prot|target_set=KRUK,BHFL

sub parse_gpi{
	# currently extracts only the taxon
	my $self = shift;
	my (
	$in_file, 
	$out_file,
	$taxa, # ref to a hash, optional
	) = @_;
	croak "Not enough arguments!" if !($in_file and $out_file);
	my $IN = open_read ( $in_file );
	my $OUT = open_write ( $out_file );
	my %map; # UP_AC => NCBI Taxon
	while (<$IN>) {
		next if /\A!/xms; # header
		next if /\A\s/xms;
		chomp;
		my @fields = split(/\t/);
		my ($taxns, $taxid ) = split /:/, $fields[5];
		next if ( $taxa and ! $taxa->{$taxid} );
		$map{$fields[0]} = $taxid;
		print $OUT "$fields[0]\t$taxid\n";
	}
	close $IN;
	close $OUT;
	return \%map;
}

########################################################################
# gpa-version: 1.1
#   --.name                  required? cardinality   GAF column #
#   01.DB                    required  1             1
#   02.DB_Object_ID          required  1             2 / 17 #vm uses isoforms if available
#   03.Qualifier             required  1 or greater  4 #vm rel types, currrently no multiple values
#   04.GO ID                 required  1             5
#   D5:Reference(s)       required  1 or greater  6 #vm currently only a single ID, only 5.5% with PMID
#   06.ECO evidence code     required  1             7 + 6 (GO evidence code + reference)
#   07.With                  optional  0 or greater  8
#   08.Interacting taxon ID  optional  0 or 1        13
#   09.Date                  required  1             14
#   10.Assigned_by           required  1             15
#   11.Annotation Extension  optional  0 or greater  16
#   12.Annotation Properties optional  0 or 1        n/a

sub parse_gpa {
	# TODO consider replacing aspects with the actual rel_symbols in gpa files
	# TODO consider making it aspect specific (to simplify the data structure)?
	# in this function original namespaces from GOA files are used  
	
	my (
		$self,
		$in_file_path,
		$map # hash ref, { UPAC => UPID } or { UPAC => TaxID }; optional
	 ) = @_;
	my $data;
	my $added =0;
	my $count = 0;
	# the hash contains only the default symbols, the others contribute ~0.1%
	my $rex_exts = qr/(\S+)\((\S+)\)/xmso;
	my $FH = open_read ( $in_file_path );
	while ( <$FH> ){
		chomp;
		my @fields = split ( /\t/ );
		next if ( @fields < 6 );
		next if substr ( $_, 0, 1) eq "\n";
		next if substr ( $_, 0, 1) eq "!";
		my $qlfr = $fields[2]; # now mandatory
		next unless $tdid2key{$qlfr}; # filtering by rel type assuming a single qualifier
		$count++;
		my $objid = $fields[1];	# UP AC OR IsoId
		my ( $upac, $ext ) = split /-/, $objid;
		my $src = $fields[0]; # the original namespace, normally UniProtKB
		my $nsgoid = $fields[3]; # full GO ID
		my ( $GONS, $goid ) = split /:/, $nsgoid;
		my $asnid;
		# Note: there are multiple lines for many $asnid
		# TODO count the number of entries with identical $asnid
		$asnid = "$objid-$qlfr-$goid"; # now isoform specific
		
		$data->{$logk}{'multiEntry'}{$asnid}++ if $data->{$GOANS}{$asnid}; # may happen e.g. for multiple ECO 
		# filtering
		if ( $map ) {
			if ( ! $map->{$upac} ) { $data->{$logk}{'notInMap'}{$upac}++; next; }
		}
				
		## Proteins
		$data->{'Proteins'}{$src}{$upac}{$GOANS}{$asnid}++; # multiple associations
#-------------------------------------------------------------------------------
		# associations
		# the 2 lines below are necessry !!
		$data->{$GOANS}{$asnid}{$src} = $objid;
		$data->{$GOANS}{$asnid}{$GONS} = $goid;
		$data->{$GOANS}{$asnid}{$qlfrk} = $qlfr;
		
		my @nsrefids = split /\|/, $fields[4]; # 
		my ( $refns, $refid ) = split /:/, $nsrefids[0]; # for now taking only one
		$data->{$GOANS}{$asnid}{$refns}{$refid} = 1; # reusing the original namespace
		my ($econs, $ecoid) = split /:/, $fields[5]; #ECO ID
		my @sup_refs = split ( /\|/, $fields[6] ); # references for evidence codes, currrently not used
		$data->{$GOANS}{$asnid}{$econs}{$ecoid} = \@sup_refs; # ECO ids with refs
		# the taxon where the interaction takes place if any
		if ( my $hostid = $fields[7] ) {
			my ( $ns, $id ) = split /:/, $hostid;
			$data->{$GOANS}{$asnid}{$ns}{$id} = 1; # Attn: changed $host => $ns !!!
		}
		# the lines commented just to reduce the size of the data structure
		#~ $data->{$GOANS}{$asnid}{$datek}{$fields[8]} = 1; # date of annotation
		#~ $data->{$GOANS}{$asnid}{$ansrck}{$fields[9]} = 1; # annotation source
		$added++;
		
		next unless $fields[10];
		# extentions
		if ( my @extens = split /\|/, $fields[10] ) { # optional field
			foreach my $extn ( @extens ) { # extension conjugations 
				my @rlexps = split /,/, $extn;
				foreach my $rlexp ( @rlexps ) { # relation expressions Relation_Symbol '(' ID ')'
					my ( $rlnsym, $nsid ) = $rlexp =~ $rex_exts; #has_regulation_target(MGI:MGI:107363)
					my @nsid = split /:/, $nsid; # multiple NSs occur
					$data->{$GOANS}{$asnid}{'extentions'}{$rlnsym}{$nsid[-2]}{$nsid[-1]} = 1;
# 					$data->{'Proteins'}{$src}{$objid}{'EXTs'}{$rlnsym}{$nsid[-2]}{$nsid[-1]} = 1; # not completely correct
				}
			}
		}
		
	}# end of while $FH
	close $FH;
	my $rejected = $count - $added;
# 	print "Associations: accepted - $added, rejected - $rejected, total - $count;\n" if $verbose;
	$data->{'GOA'} ? return $data : carp "No data to return: $!";
}

sub parse_gaf {
	# TODO see if tax id in necessary at all
	# TODO see if it's better to use e.g. 'ptn2bp' iso 'P'
	# TODO consider making it aspect specific (to simplify the data structure)?
	# in this function original namespaces from GOA files are used  
	my (
		$self,
		$in_file_path,
		$map # hash ref, { UPAC => UPID }; optional
	 ) = @_;
	my $data;
	my $added =0;
	my $count = 0;
	my $FH = open_read ( $in_file_path );
	while ( <$FH> ){
		chomp;
		my @fields = split ( /\t/ );
		next if ( @fields < 15 );
		next if substr ( $_, 0, 1) eq "\n";
		next if substr ( $_, 0, 1) eq "!";
		$count++;
		my $objid = $fields[1];	# normally UP accession
		my $src = $fields[0]; # the original namespace, normally UniProtKB
		my $nsgoid = $fields[4];
		my ( $GONS, $goid ) = split /:/, $nsgoid;
		my $asnid;
		# Note: there multiple lines for many $asnid
		# TODO count the number of entries with identical $asnid
		$asnid = "$objid-$goid";
		my $aspt = $fields[8]; # 'P'|'C'|'F'

		# filtering
		if ( $map ) {
			if ( ! $map->{$objid} ) { $data->{$logk}{'notInMap'}{$objid}++; next; }
		}
		my $qlfr = $fields[3];
		if ( $qlfr ) {
			my $qtest = substr $qlfr, 0, 3;
			#~ print "Q test: $qtest\n";
			if ( $qtest eq 'NOT' ) { $data->{$logk}{'negative'}{$asnid}++; next; } 
		}		
				
		## Proteins
		# Note: taxon - always NCBI taxonomy;
		my @taxa = split ( /\|/, $fields[12] ); # 'TAXON'
		my $nstxid = shift @taxa; # the second taxid if any refers to the host rather than the source
		my ( $txns, $txid ) = split /:/, $nstxid; # $txns is $txnSrc
		$data->{'Proteins'}{$src}{$objid}{$txns} = $txid;	
		$data->{'Proteins'}{$src}{$objid}{$GOANS}{$asnid} = $aspt; # multiple associations
		# the commented lines below are perfectly fine, commented to reduce the size
		#~ $data->{'Taxa'}{$txns}{$txid}{$objid} = 1;
		# GO terms - reusing the original namespace	$GONS, normally always 'GO'		
		#~ $data->{'Terms'}{$GONS}{$goid}{$aspk} = $aspt;
#-------------------------------------------------------------------------------
		# associations
		# the 2 lines below are necessry !!
		$data->{$GOANS}{$aspt}{$asnid}{$src} = $objid;
		$data->{$GOANS}{$aspt}{$asnid}{$GONS} = $goid;
		# the commented lines below are perfectly fine, commented to reduce the size
			#~ $data->{$GOANS}{$aspt}{$asnid}{$ifmk}{$ifmid} = 1 if $nsifmid; # fixed key for isoform !! double check !!!
		#~ $data->{$GOANS}{$aspt}{$asnid}{$qlfrk}{$qlfr}++ if $qlfr; # 'QUALIFIER' do we need this?
		my $nsrefid = $fields[5]; # a single reference according to README, normally PubMed
		my ( $refns, $refid ) = split /:/, $nsrefid;		
		$data->{$GOANS}{$aspt}{$asnid}{$refns}{$refid} = 1; # reusing the original namespace
		my @sup_refs = split ( /\|/, $fields[7] ); # references for evidence codes
		$data->{$GOANS}{$aspt}{$asnid}{$ecok}{$fields[6]} = \@sup_refs; # fixed key for eco refs
# 		$data->{$GOANS}{$aspt}{$asnid}{$ecok}{$fields[6]} = \@sup_refs; # fixed key for eco refs
		# the second taxon - where the action takes place (if any)
		map { my ( $ns, $id ) = split /:/; $data->{$GOANS}{$aspt}{$asnid}{$host}{$id} = 1 } @taxa if @taxa;
		#~ $data->{$GOANS}{$aspt}{$asnid}{$datek}{$fields[13]} = 1; # date of annotation
		#~ $data->{$GOANS}{$aspt}{$asnid}{$ansrck}{$fields[14]} = 1; # annotation source
		
		$added++;
		
	}# end of while $FH
	close $FH;
	my $rejected = $count - $added;
	print "Associations: accepted - $added, rejected - $rejected, total - $count;\n" if $verbose;
	$data ? return $data : carp "No data to return: $!";
}

########################################################################

=head2 gpa2onto

 Usage - $Goa->gpa2onto ( $ontology, $data, )
 Returns - a hash with added proteins as the keys
 Args -
	 1. OBO::Core::Ontology object,
	 2. ref to a hash, output of parse
 Function - adds GO associations ( and optionally protein terms ) to ontology

=cut

# parse() should be always run with a map:
# full up map for BP, full or ontology specific map for the others 
# (the filtering will be done by the ontology and the protein terms must be retrieved from ontology anyway ) )
sub gpa2onto {
	# needs a SINGLE aspect/relation type !! TODO check if this is really necessary
	# expects all the filtering done before !!!
	# proper filtering is essential for excluding extraneous proteins
	# no need for a map here: the filtering is done by GO terms in case of 'P';
	# by proteins otherwise (no new terms created)
	# TODO proper error handling
	# introduce terms for associations?
	my (
	$self,
	$onto,
	$data,
	$rlskey, # one of 'ptn2bp', 'ptn2cc', 'ptn2mf' NOTE: must be this way !
	) = @_ ;
	my $reqargs = 4;
	croak "The function needs $reqargs arguments" if @_ < $reqargs;
	
	#------------------------- PREAMBULE -----------------------------------------
	# setting rels in the onto 
	my $rltp; # OBO::Core::RelationshipType
	my @rlskeys = ( $rlskey );
	my $tpdefs = set_props ( $onto, \%props, \@rlskeys );

	# testing the parent terms in the ontology
	my $parents = test_prns ( $onto, \%prns );
	my @parents = ( $parents->{'ptn'} );
	# hashes to collect terms
	my %go_terms; # { GO_id => OBO::Core::Term object }
	my %proteins; # {protein term id => OBO::Core::Term object}
	my %new_proteins; # {UP_AC =>  1} # NOTE: either all proteins are new or none
	my $fs = ':';
	#-----------------------------------------------------------------------------
	$rltp = $tpdefs->{ $rlskey };
	my $rltp_id = $rltp->{'ID'};
	foreach my $asnid ( keys %{$data->{$GOANS}} ) {
		next unless $data->{$GOANS}{$asnid}{$qlfrk} eq $rltp_id; # as specified in GPA files
		my $asn = $data->{$GOANS}{$asnid};
		my $objectid = $asn->{$ptnSrc};
		my ($upac, $ext) = split /-/, $objectid;
		my $ptnid = $PRTNS.$fs.$upac;
		my $goid = $GONS.$fs.$asn->{$GONS};
		# GO terms (all must be present already in the onto)
		my $gotm = retrieve_term ( $onto, $goid, \%go_terms ) or next;
		# protein terms (new terms are created only in case of 'P' aspect)
		my $ptn = retrieve_term ( $onto, $ptnid, \%proteins );
		next if ! $ptn && ! $add_ptntm{$rlskey}; # one of the two must be true
		if ( ! $ptn ) { # implies $asp eq 'P'
			$ptn = add_new_term ( $onto, $ptnid, \@parents, \%proteins );
			$new_proteins{$upac}++;
		}
		create_triple ( $onto, $ptn, $rltp, $gotm );
	} # end of foreach $asnid
	return \%new_proteins;
}

################################################################################

=head2 gpa2rdf

  Usage    - $GoaParser->gpa2rdf($input_file, $out_file, $base, $ns);
  Returns  - RDF file handle
  Args     - 1. Full path to the GOA file
  			 2. Full path for writing RDF
  			 3. base URI (e.g. 'http://www.semantic-systems-biology.org/')
  			 4. name space (e.g. 'SSB', could be as well '')
  Function - converts an assoc. file to RDF 
  
=cut



sub gpa2ttl {
# Note: rdf:bag is used to provide resolvable URIs
	my ( 
	$self,
	$data, # output from parse_gpa()
	$rdf_path, # for writing
	) = @_;
	croak "Not enough arguments!" if ( @_ < 3 );
	
		
	my $uris = \%uris;
	my $props = \%props;
	my $fs = '_';
	my $buffer = '';
	my $OUT = open_write ( $rdf_path );
	my $s = " ;\n\t";
	my $sp = " ,\n\t\t";

	### Preambule of RDF file
	$buffer = write_ttl_preambule ( $uris,  );

	### Properties
	$buffer .= write_ttl_header ( 'Properties' );
	$buffer .= write_ttl_properties ( $uris, $props, \@rlskeys );
	print $OUT $buffer; $buffer = "";

########################################################################
	### Classes ###
	$buffer = write_ttl_header ( 'Classes' );
	print $OUT $buffer; $buffer = "";
	
	my $goa_class = 'SIO_000897'; # 'association'
	my $src = $ptnSrc;
	# TODO generalize to use sources other than UP ??
	# this will minimize hard coding ( now $ptnSrc (UniProtKB) is used )
	my $ptns = $data->{'Proteins'}{$src};

	foreach my $upac ( sort keys %{$ptns} ) {
		print $OUT "\n### $uris->{'uniprot'}$upac ###\n";
		print $OUT "\nuniprot:$upac rdfs:subClassOf sio:SIO_010043 .\n"; 
		my $bag_bfr;
		$bag_bfr .= "goa:$upac a rdf:Bag";
		my $rel_bfr = "uniprot:$upac";
		my $flag = 1;
		## associations
		my $asns = $ptns->{$upac}{$GOANS};
		foreach my $asnid (sort keys %{$asns} ) {
			my $asn = $data->{$GOANS}{$asnid};
			my $qlfr = $asn->{'qualifier'}; # OBO rel ID
			my $goaid = "GOA$fs$asnid";
			my $goid = $asn->{$GONS}; #print Dumper($rels);
			my ( $NS, $id ) = @{ $props->{$tdid2key{$qlfr}} };
			my $relid = $NS.$fs.$id;
			my $objectid = $asn->{'UniProtKB'};
			$bag_bfr .= $s."rdf:li ssb:$goaid";
			my $buffer;
			$buffer .= "ssb:$goaid a rdf:Statement";
			$buffer .= $s."rdf:subject uniprot:$upac";
			$buffer .= $s."rdf:predicate obo:$relid";
			$buffer .= $s."rdf:object obo:$GONS$fs$goid";
			my ( @keys, $property, $first );
			$buffer .= $s."skos:relatedMatch \"$nss{ptn}:$objectid\"" if $objectid ne $upac;
			
			@keys = sort keys %{$asn->{'PMID'}};
 			$first = shift @keys;
			# $buffer .= $s."skos:relatedMatch \"$nss{pm}:$first\"" if $first;
 			$buffer .= $s."skos:relatedMatch pubmed:$first" if $first;
			map { $buffer .= $sp."pubmed:$_"; } @keys;
			
			@keys = sort keys %{$asn->{'ECO'}};
 			$first = shift @keys;
			$buffer .= $s."rdfs:isDefinedBy obo:ECO$fs$first" if $first;
			map { $buffer .= $sp."obo:ECO$fs$_"; } @keys;
			
			@keys = sort keys %{$asn->{$host}};
 			$first = shift @keys;
			# $buffer .= $s."skos:relatedMatch \"$nss{txn}:$first\"" if $first;
 			$buffer .= $s."skos:relatedMatch obo:$TXNNS$fs$first" if $first;
			map { $buffer .= $sp."obo:$TXNNS$fs$first if $first"; } @keys;
			
			print $OUT "$buffer .\n";
			if ( $flag ) {
				$rel_bfr .= " obo:$relid obo:$GONS$fs$goid";
				$flag = 0;
			} else {
				$rel_bfr .= $s."obo:$relid obo:$GONS$fs$goid";
			}
		} # foreach asnid
		print $OUT "$bag_bfr .\n";
		print $OUT "$rel_bfr .\n";
	} # foreach upac
	print $OUT "\n# Generated with $0 ".__date."\n";
	close $OUT;
}

sub filter_by_aspect {
	my $self = shift;
	my ($in_file, $out_file, $aspect) = @_;
	croak "Not enough arguments!" if !($in_file and $out_file and $aspect);
	my $IN = open_read ( $in_file );
	my $OUT = open_write ( $out_file );
	while (<$IN>) {
		chomp;
		next if /\A!/xms; # !gaf-version: 2.0
		my @assoc = split(/\t/);
		foreach(@assoc){
			$_ =~ s/^\s+//;
			$_ =~ s/\s+$//;
		}
		print $OUT "$_\n" if ($assoc[8] eq $aspect);
	}
	close $IN;
	close $OUT;
}

1;
