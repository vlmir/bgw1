#! /usr/bin/perl
package parsers::Goa;

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

use auxmod::SharedVars qw(
%nss
);

#--------------------- Global vars ---------------------------------------------
# TODO check the use of all Global vars
my $GOANS = $nss{'goa'};
my $PRTNS = $nss{'tlp'};
my $TXNNS = $nss{'txn'};
my $PMNS = $nss{'pm'}; # PubMed
my $SSB = $nss{'ssb'}; # TODO rename SSB 
my $GONS = 'GO'; # used in all functions but redefined in parse() to the same value

my $goans = lc $GOANS;
my $tlpns = lc $PRTNS;
my $pmns = lc $PMNS;
my $ssb = lc ($SSB);
my $econs = 'eco';
my $kdlm = '+';

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

my $logk = 'log';

my @rlskeys = qw ( gp2bp gp2cc gp2mf );
my %tdid2key = (
'involved_in' => 'gp2bp',
'part_of' => 'gp2cc',
'enables' => 'gp2mf'
);
########################################################################

sub new {
	my $class = $_[0];
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
 gpa-version: 1.1
   --.name                  required? cardinality   GAF column #
   01.DB                    required  1             1
   02.DB_Object_ID          required  1             2 / 17 #vm uses isoforms if available
   03.Qualifier             required  1 or greater  4 #vm rel types, currrently no multiple values
   04.GO ID                 required  1             5
   D5:Reference(s)       required  1 or greater  6 #vm currently only a single ID, only 5.5% with PMID
   06.ECO evidence code     required  1             7 + 6 (GO evidence code + reference)
   07.With                  optional  0 or greater  8
   08.Interacting taxon ID  optional  0 or 1        13
   09.Date                  required  1             14
   10.Assigned_by           required  1             15
   11.Annotation Extension  optional  0 or greater  16
   12.Annotation Properties optional  0 or 1        n/a
=cut
sub parse {
	# TODO consider replacing aspects with the actual rel_symbols in gpa files
	# TODO consider making it aspect specific (to simplify the data structure)?
	# in this function original namespaces from GOA files are used  
	
	my (
	$self,
	$data_path,
	$asp,
	$map # hash ref, { UPAC => UPID } or { UPAC => TaxID }; optional
	) = @_;
	my %asp2qlfr = (
	'cc' => 'part_of',
	'mf' => 'enables',
	'bp' => 'involved_in',
	);
	my $qlfr = $asp2qlfr{$asp};
	my $data;
	my $added =0;
	my $count = 0;
	# the hash contains only the default symbols, the others contribute ~0.1%
	my $rex_exts = qr/(\S+)\((\S+)\)/xmso;
	my $FH = open_read ( $data_path );
	while ( <$FH> ){
		chomp;
		next if substr ( $_, 0, 1) eq "!"; # SIC!
		my @fields = split ( /\t/ );
		next if ( @fields < 6 );
		next unless $fields[2] eq $qlfr;
		$count++;
		my $objid = $fields[1];	# UP AC OR IsoId
		my ( $upac, $ext ) = split /-/, $objid;
		my $src = $fields[0]; # the original namespace, normally UniProtKB
		my $nsgoid = $fields[3]; # full GO ID
		my ( $GONS, $goid ) = split /:/, $nsgoid;
		my $asnid;
		# Note: there are multiple lines for many $asnid
		# TODO count the number of entries with identical $asnid
		$asnid = $objid.$kdlm.$goid; # now isoform specific
		# may happen e.g. for multiple ECO; 
		# 88431 for human refprot, why so many ???
		$data->{$logk}{'multiEntry'}{$asnid}++ if $data->{$GOANS}{$asnid};
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
	my @chunks = split /\./, $data_path;
	pop @chunks;
	my $path = join '.', @chunks;
	my $json_path = $path . '.' . $asp . '.json';
	my $var = encode_json $data;
	my $OUT = open_write ( $json_path );
	print $OUT $var;
# 	print "Associations: accepted - $added, rejected - $rejected, total - $count;\n" if $verbose;
	$data->{'GOA'} ? return $data : carp "No data to return: $!";
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

1;
