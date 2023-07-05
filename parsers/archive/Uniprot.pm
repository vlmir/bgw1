package parsers::Uniprot;

use strict;
use warnings;
use Carp;

use OBO::Core::Dbxref;
use OBO::Core::Term;
# use SWISS::Entry;
use Text::Wrap qw($columns &wrap);

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};
use auxmod::SharedSubs qw( 
char_http
__date
test_prns
set_props
create_triple
add_new_term
retrieve_term
open_read
open_write
write_ttl_preambule
write_ttl_properties
);
use auxmod::SharedVars qw(
$rex_first_word
$rex_dot
$rex_semicln
$rex_prnths
$rex_brcs
$rex_brkts
$rex_dblq
%uris
%nss
%props
%prns
%organisms
);
## TODO replace stirng with the variables below
my $GNNS = $nss{'gn'};
my $PRTNS = $nss{'ptn'};
my $TXNNS = $nss{'txn'};
my $DSSNS = $nss{'dss'};
my $EMBLNS = $nss{'insdc'};
my $SSBNS = $nss{'ssb'};

my $gnns = lc $GNNS;
my $ptnns = lc $PRTNS;
my $dssns = lc $DSSNS;
my $emblns = lc $EMBLNS;
my $ssbns = lc ($SSBNS);

# keys used in the hashes:
my $ptnk = 'AC';
my $ptnnmk = 'ID';
my $dssk = 'DISEASE';
my $gnk = 'GeneID';
my $txnk = 'NCBI_TaxID';
my $xrfk = 'EMBL';
my $defk = 'DE';
my $nmk = 'NAME';
my $synk = 'SYNONYM';
my $ftk = 'FT';
my $logk = 'log'; # TODO replace logging in the output data structure with with printing to STD or STDERR

# global regular expressions, only specific for UniProt
my $rex_line = qr/^(\w\w)\s{3}(.+)$/xmso;
my $rex_cc = qr/^-\!-\s(.+?):\s(.+)$/xmso;
my $rex_ft = qr/^(\w+)\s+(\d+)\s+(\d+)\s{7}(.+)/xmso; # matches the first line of a FT block; TODO refine
my $rex_id = qr/\AID\s{3}(\w+)/xmso; # $1 - UP ID, $2 - seq length
my $rex_ac = qr/^AC\s{3}(\w+)/xmso;
my $rex_short_name = qr/^.+Short=(.+?);/xmso; # TODO include all other short names?
my $rex_value = qr/^.+=(.+?);/xmso; # the first value
# OX   NCBI_TaxID=284812;
my $rex_tx = qr/^OX\s{3}NCBI_TaxID=(\d+)/xmso;
my $rex_txid = qr/^\D+(\d+)/xmso;
# SQ   SEQUENCE   842 AA;  93231 MW;  A544C5C454BC55C7 CRC64;
#      MVAFTPEEVR NLMGKPSNVR NMSVIAHVDH GKSTLTDSLV QKAGIISAAK AGDARFMDTR
my $rex_seq = qr/^SQ\s{3}SEQUENCE\s+(\d+).+?\n(.+)\z/xmso; # $1 seq length, $2 - seq
my $rex_ex_ln = qr/^\s+(\S+.*)$/xmso;
# 'GeneID; 398428; -.'
my $rex_gnid = qr/^$gnk;\s(\d+)/xmso;

my @rlskeys = ( 'ptn2txn', 'ptn2ptm', 'ptn2dss' );
############################### new ############################################

sub new {
 my $class = $_[0];
 my $self = {};
 bless ( $self, $class );
 return $self;
}

################################## parse #######################################
=head2 parse

 Usage - $UniProtParser->parse ( $uniprot_file_path, $uniprot_map )
 Returns - ref to a hash { UniProtAC => SWISS::Entry object }
 Args -
 	1. UniProt data file path,
 	2. ref to a hash { UniProtAC => UniProtID } to filter by, optional
 Function - parses UniProt data file

=cut
# Note: there may be a limited number of ACs (like 26) with multiple UP ID
# the relation between UP primary AC and ID in idmapping is 1:1 but not in the data !!! 
# the relation between UP primary AC and taxon ID in idmapping is n:1 !!! 
# TODO log multiple ID, taxa, defs
# TODO move the handling of MOD to uniprot2onto() and uniprot2rdf()
# should be able to handle multiple diseases
sub parse {
# About 8 times faster than parse_dat()
# 	shift @_;
	my (
	$self,
	$uniprot_file_path,
	$gnid2upac_path, # for writing
	$syns, # for mapping to MOD terms
	$up_map # optional
	 ) = @_;
	my $all_mod_syns = $syns->{'synonym'}; 
	my @mod_syns = keys %{$all_mod_syns};
	my $data; # ref to a hash
	my $no_gene_id =0;
	my $multiple_genes = 0;
	my $multiple_proteins = 0;
	my $no_GN = 0;
	my $multiple_GNs = 0;
	my $count_mod_types = 0;
	my $count_mods = 0;
	my $count_mod_prots = 0;
	my $all = 0;
	my $accepted = 0;
	my $rejected = 0;
	my $FH = open_read ( $uniprot_file_path );
	local $/ = "\n//\n";
	my %gnid2upac; # (geneid => {upacc => count})
	while ( <$FH> ) {
		my $txt = $_; # $_ is still defined
		$all++;
		my $entry = {};
		my @lines = split /\n/, $txt;
		pop @lines; # removing the trailing '//'
		map { chomp $_ } @lines;
		
		### building a structure containing complete data for the current entry --------------------------------------------
		map { $_ =~ $rex_line ? push @{$entry->{$1}}, $2 : push @{$entry->{'SQ'}}, substr $_, 5; } @lines;
		next unless my ( $id ) = $entry->{'ID'}[0] =~ $rex_first_word;
		next unless my ($ac) = $entry->{'AC'}[0] =~ $rex_semicln;
		#------------------------ filtering ----------------------------------------
		# the relation between UP primary AC and ID in idmapping is 1:1 but not in the data !!!
		# TODO fix the filtering
# 		my $ptnnm = $id or carp "Protein: $ac has no ID"; # the UPID in the data entry
# 		if ( $up_map ) {
# 			my $upmapid = $up_map->{$ac};
# 			next unless $upmapid; # not in the map, seem to be all fragments
# 			next unless $id eq $upmapid; # is it still needed?
# 		}
		next unless my ( $txid ) = $entry->{'OX'}[0] =~ $rex_txid;

		## ---------------------------------------- DE lines --------------------------------------------------------------
		
# TODO proper treatment of cases like this one:		
## DE   SubName: Full=Cell division cycle 2, G1 to S and G2 to M, isoform CRA_a {ECO:0000313|EMBL:EAW54209.1};
## DE   SubName: Full=Cyclin-dependent kinase 1 {ECO:0000313|Ensembl:ENSP00000397973};
## examples of xrefs:
# DE   RecName: Full=Elongation factor 2 {ECO:0000313|Ensembl:ENSP00000397973};
# DE            Short=EF-2 {ECO:0000313|EMBL:EAW54209.1};
# DE   RecName: Full=Kinetochore protein Nuf2-A;
# DE            Short=xNuf2;
# DE   AltName: Full=Cell division cycle-associated protein 1-A;
# TODO include proper xrefs for defs and syns 
		next unless my ( $first_de, @syns ) = map {$_ =~ $rex_value} @{$entry->{'DE'}};
		my ( $def, $xrefs ) = $first_de =~ $rex_brcs ?  ( $1, $2 ) : ( $first_de, 'ECO:0000000' );
## $2 holds xrefs in the form 'ECO:0000305' or 'ECO:0000313|Ensembl:ENSP00000397973' (an ECO ref is now mandatory); 
## Attn: 'ECO:0000303|PubMed:24256100, ECO:0000303|Ref.4' also occur
		my @xrefs = split /, /, $xrefs if $xrefs;
		foreach my $xref ( @xrefs ) {
			my ( $eco, $ref ) = split /\|/, $xref; # $eco must be there, not necessarily $ref
			push @{$data->{'Protein'}{$ptnk}{$ac}{$defk}{$def}{$eco}}, $ref;
		}
		foreach my $syn ( @syns ) { # ECO:0000000 ! evidence; not found in the complete human proteome; used here for missing ECO in DE lines
			my ( $syn_name, $xrefs ) = $syn =~ $rex_brcs ?  ( $1, $2 ) : ( $syn, 'ECO:0000000' );
			my @xrefs = split /, /, $xrefs;
			foreach my $xref ( @xrefs ) {
				my ( $eco, $ref ) = split /\|/, $xref; # $eco must be there, not necessarily $ref
				push @{$data->{'Protein'}{$ptnk}{$ac}{$synk}{$syn_name}{$eco}}, $ref;
			}
		}
		
		#---------------------------- $data ----------------------------------------
		
		$data->{'Protein'}{$ptnk}{$ac}{$txnk}{$txid}++;
		$data->{'Protein'}{$ptnk}{$ac}{$ptnnmk}{$id}++;
# 		$data->{'Protein'}{$ptnk}{$ac}{$synk}{$short_name}++ if $short_name;
		$data->{'Taxon'}{$txnk}{$txid}{$ptnk}{$ac}++;
		map { $data->{'Protein'}{$ptnk}{$ac}{$gnk}{$1}++ if $_ =~ $rex_gnid } @{$entry->{'DR'}};
# 		map { $data->{'Gene'}{$gnk}{$1}{$ptnk}{$ac}++ if $_ =~ $rex_gnid } @{$entry->{'DR'}};
# 		map { print $OUT "$ac\t$1\n" if $_ =~ $rex_gnid } @{$entry->{'DR'}};
		map { $gnid2upac{$1}{$ac}++ if $_ =~ $rex_gnid } @{$entry->{'DR'}};
		
		## Attn: @lines re-assigned below -------------------------------------------
		
		@lines = @{$entry->{'CC'}};
# CC   -----------------------------------------------------------------------
# CC   Copyrighted by the UniProt Consortium, see http://www.uniprot.org/terms
# CC   Distributed under the Creative Commons Attribution-NoDerivs License
# CC   -----------------------------------------------------------------------
		@lines = @lines[0 .. $#lines -4]; # removing the last 4 lines
# 		my $ccs = parse_block ( \@lines, $rex_cc, 4 , ' ' );
		my $ccs = _parse_cc( \@lines, $dssk );
		
		
		
		#------------------------ Diseases -----------------------------------------
		# TODO proper treatment of cases like this:
		# CC   -!- DISEASE: Nephronophthisis 14 (NPHP14) [MIM:614844]: An autosomal
		# CC   -!- DISEASE: Joubert syndrome 19 (JBTS19) [MIM:614844]: A form of
		# the authentic name spaces are reused
		foreach my $dssln (@{$ccs->{$dssk}}) {
# 			unless ( $dssln =~ $rex_brkts ) { $data->{$logk}{'noDiseaseId'}{$ac}++; next};
			my ( $header, $text ) = $dssln =~ $rex_brkts ? ( $1, $3 ) : next;
			
			my ( $dssns, $dssid ) = split ( /:/, $2 );
			if ( ! $dssid ) { $data->{$logk}{'badDiseaseId'}{$ac}++; next };
			$data->{'Protein'}{$ptnk}{$ac}{$dssk}{$dssns}{$dssid}++;
			$data->{'Taxon'}{$txnk}{$txid}{$dssk}{$dssns}{$dssid}++;
			$data->{$dssk}{$dssns}{$dssid}{$ptnk}{$ac}++;
			# isn't it better to keep the acronym in the name ?
			my ( $name, $acro ) = $header =~ $rex_prnths;
			$data->{$dssk}{$dssns}{$dssid}{$nmk}{$name} = $acro if $acro; # $dss name;
			if ( $text ) {
				my ($text, $note) = split /\sNote=/, $text; # assuming a single Note;
				( $text, my $refs ) = ( $1, $2 ) if $text =~ $rex_brcs; # $2 contains refs in the form {ECO....|...} or {ECO:...}
				$text = "($acro)".$text if $acro; # normally is always provided
				$data->{$dssk}{$dssns}{$dssid}{$defk}{$text} = $acro;
				$data->{$dssk}{$dssns}{$dssid}{$synk}{$acro}++;
			}
			else { $data->{$logk}{'noDiseaseDef'}{$ac}++; }
		} # end of foreach 
		
		#---------------------------- PTMs -----------------------------------------
		## FT   MOD_RES       1      1       N-acetylmethionine. {ECO:0000269|Ref.5}. - since 2015
## 89 different CARBOHYD modifications in the human proteome:
# 		mironov@genetools:/norstore/project/ssb/workspace/data/download/uniprot$ grep CARBOHYD 9606.txt | grep '^FT ' | cut -c 35- | sort -u | wc -l
# 89
# all include parens; e.g.:
# C-linked (Man).
# C-linked (Man). {ECO:0000250}.
# C-linked (Man); partial.
# N-linked (Glc) (glycation).
# N-linked (Glc) (glycation); alternate.
# N-linked (Glc) (glycation); in
# N-linked (Glc) (glycation); in Hb A1c.
# N-linked (Glc) (glycation); in PHF-tau;
# N-linked (GlcNAc...)
# N-linked (GlcNAc...) (complex). ## apparently not mod.obo
# N-linked (GlcNAc...) (complex); atypical.
# N-linked (GlcNAc...) (complex); partial;
# N-linked (GlcNAc...) (high mannose and
# N-linked (GlcNAc...) (high mannose or
# N-linked (GlcNAc...) (high mannose).
# N-linked (GlcNAc...) (keratan sulfate).
# N-linked (GlcNAc...). {ECO:0000255,
# N-linked (GlcNAc...). {ECO:0000255|HAMAP-
		@lines = @{$entry->{'FT'}} if $entry->{'FT'}; # 'FT     ' removed
		my $flag = 0;
# 		my @types = ( 'MOD_RES', 'LIPID', 'CARBOHYD' );	# TODO fix CARBOHYD ?
		my @types = ( 'MOD_RES', 'LIPID', );		
		foreach my $type ( @types ) {
			my $ptms = _parse_ft( \@lines, $type ); #print Dumper ($ptms) if %{$ptms};
			foreach my $line ( @{$ptms->{$type}} ) { # mothing happens if no modifications of $type
				my (
					$upptm,
					$tail, # everything after the first ';', e.g 'by MAPK sty1'
					$qualifier, # e.g. 'By similarity'; seems to be absent in refprots, certainly in CCO
				);
				$count_mods ++; # for each modification
				$count_mod_prots ++ if $flag == 0;
				$flag = 1;
				if ( $line =~ $rex_dot ) {
					( $upptm, my $refs ) = ( $1, $2 ); # $2 is expected to contain newly introduced refs in the form {....}
				} else {
					carp "line '$line is truncated";
					next;
				}
				if ( $upptm =~ $rex_semicln ) {	# capturing everything before and after the first ';'
					( $upptm, $tail ) = ( $1, $2 );
				}
				$count_mod_types++ unless $data->{$ftk}{$type}{$upptm};
				
				## fetching MOD ontology ids
				my $syn_name = "$type $upptm"; # modified AA name as used in MOD synonyms ids e.g 'MOD_RES Phosphohistidine'
				my @modids;
				@modids = keys %{$all_mod_syns->{$syn_name}{'MOD'}}; # bare MOD ids, multiple may occur
				$syn_name = $upptm  if @modids == 0;
				@modids  = keys %{$all_mod_syns->{$syn_name}{'MOD'}} if @modids == 0; # exact match with other synonyms
				# partial matches:
				if ( @modids == 0) {
					my %mod_ids;
					my $up_base_name = $upptm =~ /\(.+\)-(\S.+)$/ ? $1 : $upptm;
					foreach my $mod_syn ( @mod_syns ) {
						if ( $mod_syn =~ /$up_base_name$/xmsi ) {
							my $ids = $all_mod_syns->{$mod_syn}{'MOD'};
							map { $mod_ids{$upptm}{$_ }++ if $ids->{$_} =~ /EXACT/xmso } keys %{$ids};
							carp "Matching 'UP $type=$upptm => MOD:$mod_syn' using base name '$up_base_name'";
						}
					}
					@modids = keys %{$mod_ids{$upptm}};
				}
				carp "No match in MOD ontology for '$type=$upptm'" if @modids == 0;
				carp "Multiple MOD terms (@modids) with synonyms for '$type=$upptm' !!" if @modids > 1;
				next unless @modids >= 1;
				
				foreach my $id ( @modids ) {
					# the assignments below should be as they are !
					# now without PTM position (not used), could change in the future
					$data->{'Protein'}{$ptnk}{$ac}{$ftk}{$type}{$upptm}++;
					$data->{'Protein'}{$ptnk}{$ac}{'MOD'}{$id}++;
					$data->{'Taxon'}{$txnk}{$txid}{$ftk}{$type}{$upptm}++;
					$data->{$ftk}{$type}{$upptm}{$ptnk}{$ac}++;
					$data->{'PTM'}{'MOD'}{$id}{$ptnk}{$ac}++;
					$data->{'PTM'}{'MOD'}{$id}{'Name'}{$syns->{'MOD'}{$id}{'name'}}++;
					$data->{'PTM'}{'MOD'}{$id}{'Def'}{$syns->{'MOD'}{$id}{'def'}}++;
					$data->{'PTM'}{'MOD'}{$id}{'Syn'}{$syn_name}++;
					$data->{'PTM'}{'MOD'}{$id}{'Syn'}{$upptm}++;
				}
			} # foreach $line
		} # foreach $type
	} # end of while
	my $OUT = open_write ( $gnid2upac_path );
	foreach my $gnid ( sort { $a <=> $b } keys %gnid2upac ) {
		map { print $OUT "$gnid\t$_\n"; } sort keys %{$gnid2upac{$gnid}};
	}
	close $OUT;
	%{$data} ? return $data : carp "No data produced!";
}

######################### uniprot2onto #########################################
# no new protein terms created
# input data filtered by the onto

sub uniprot2onto {
	# TODO diseases should be inplemented as in uniprot2rdf ?
	# TODO take the project acronym from $onto to be used in refs
	my (
	$self,
	$onto,
	$data, # output of parse()
	) = @_;
	#------------------------- PREAMBULE -----------------------------------------
	# setting rels in the onto
	
	my $tpdefs = set_props ( $onto, \%props, \@rlskeys );
	# testing parent terms in the ontology
	my $parents = test_prns ( $onto, \%prns );
	# hashes to collect terms
	my %ptns = (); # UP AC => protein term; used within diseases and by parseIdMap
	my %gns = (); # map GeneID=>UPAC, to be returned
	my %ptms = (); # modifided residue name => modifided residue term
	my %taxa = (); # NCBI taxon ID => taxon term
	my %dsss = (); # OMIM ID => disease term
	my %log; # not used yet
	my $fs = ':';
	my $onto_name = $onto-> name();
	
	#------------------------- proteins ------------------------------------------
	# no new protein terms created
	
	my $rltp; # needs to be declare here !
	foreach my $upac ( keys %{$data->{'Protein'}{$ptnk}} ) {
		my $protein =  $data->{'Protein'}{$ptnk}{$upac};
		# all the protein terms are expected to be present in the ontology
		# each protein is extracted only once
		my $ptn_id = $PRTNS.$fs.$upac; #print "acc: $upac; id: $ptn_id\n";
		my $ptn = $onto->get_term_by_id ( $ptn_id ) or next; # filtering

		# name; UP ID, should be single
		my @ptnids = keys %{$protein->{$ptnnmk}}; #print "names: @ptnids\n";
		carp "Protein: $ptn_id has UPIDs: @ptnids" if @ptnids > 1;
		$ptnids[0] ? $ptn->name ( $ptnids[0] ) : carp "Protein: $ptn_id has no UPID\n";
		
		# def(s); UP DE, should be single
		my @defs = keys %{$protein->{$defk}};
		carp "Protein: $ptn_id has full names: @defs" if @defs > 1;
		$defs[0] ? $ptn->def_as_string ( $defs[0], "[]" ) : carp "Protein: $ptn_id has no full name\n";

		# synonyms (if the hash is empty nothing happens)
		my @keys = keys %{$protein->{$synk}};
# 		map { $ptn->synonym_as_string( $_, '[]', 'EXACT' ) } @keys if @keys;
		map { $ptn->synonym_as_string( $_, '[]', 'EXACT' ) } @keys;
		
		# map GeneID UPAC	
		map { $gns{$_}{$upac}++; } keys  %{$protein->{$gnk}};
		
		$ptns{$upac} = $ptn; # used in diseases

		#---------------------------- taxon ----------------------------------------
		# the relation between UP primary AC and tax ID in idmapping is 1:1 !!!		
		my @txnids = keys %{$protein->{$txnk}};
		# some sanity checks,  should never happen
		if ( @txnids == 0 ) {
			carp "Protein $ptn_id' has no taxon ID!";
			next;
		}
		print "Protein: $ptn_id' has taxon IDs: @txnids\n" if @txnids > 1;
		$rltp = $tpdefs->{'ptn2txn'};
		my @txnprns = ( $parents->{'txn'} );
		foreach my $id ( @txnids ) { # bare NCBI taxon ID
			my $txn_id = $nss{'txn'}.$fs.$id;
			my $txn = retrieve_term ( $onto, $txn_id, \%taxa );
			$txn = add_new_term ( $onto, $txn_id, \@txnprns, \%taxa) unless $txn;
			# TODO take the name from UP
			$txn-> name ( $organisms{$id}->[0] );
			$txn-> def_as_string ( $organisms{$id}->[1], "[$onto_name:team]" );
# 			$onto->create_triple ( $ptn, $rltp, $txn );
			$onto = create_triple ( $onto, $ptn, $rltp, $txn );
		}

		#-------------------------- PTMs -------------------------------------------

		$rltp = $tpdefs->{'ptn2ptm'};
# 		$rltp = $tpdefs->{'ptm2ptn'};
		my @ids = keys %{ $protein->{'MOD'} }; # bare MOD ids
		my @ptmprns = ( $parents->{'ptm'} );
		foreach my $id ( @ids ) {
			my $mod = $data->{'PTM'}{'MOD'}{$id};
			my $ptm_id = "MOD:$id";
			my $ptm = retrieve_term ( $onto, $ptm_id, \%ptms );
			$ptm = add_new_term ( $onto, $ptm_id, \@ptmprns, \%ptms) unless $ptm;
			$ptm-> name ( (keys %{$mod->{'Name'}})[0] );
			$ptm-> def_as_string ( (keys %{$mod->{'Def'}})[0], "[]" );
			my @syns = sort keys %{$mod->{'Syn'}};
			map {$ptm->synonym_as_string ( $_, "[]", 'EXACT' )} @syns;
			$onto = create_triple ( $onto, $ptn, $rltp, $ptm );
# 			$onto = create_triple ( $onto, $ptm, $rltp, $ptn );
		}
	} # end of foreach $upac
	
	#============================ diseases =======================================
	# TODO Consider treating PTMs and taxa this same way ?
	my $dsss = $data->{$dssk}{'MIM'};
	$rltp = $tpdefs->{'ptn2dss'};
	my @dssprns = ( $parents->{'dss'} );
	foreach my $id ( keys %{$dsss} ) {
		my $disease =  $data->{$dssk}{'MIM'}{$id};
		my $dss_id = $nss{'dss'}.$fs.$id;
		my $dss = add_new_term ( $onto, $dss_id, \@dssprns, \%dsss);
		my @names = sort keys %{$disease->{$nmk}};
# 		carp "Disease: $dss_id has muliple names: @names !" if @names > 1; # ~100 entries
		my $name = shift @names;
		$dss-> name ( $name );
		my $acro = $disease->{$nmk}{$name};
		$dss-> synonym_as_string ($acro, "[$onto_name:team]", 'EXACT' ) if $acro;
		map { $dss-> synonym_as_string ($_, "[$onto_name:team]", 'RELATED' ) } @names if @names;
		map { $dss-> synonym_as_string ($disease->{$nmk}{$_}, "[$onto_name:team]", 'RELATED' ) } @names if @names;
		
		my @defs = sort keys %{$disease->{$defk}};
# 		carp "Disease: $dss_id has muliple descriptions: @defs !" if @defs > 1; # ~100 entries
		my $def = join "; ", @defs;
		$def =~ tr/"/'/;
		$dss-> def_as_string ( $def, "[$onto_name:team]" );
		my @keys = keys %{$disease->{$ptnk}};
		map { my $ptn = $ptns{$_} or next; 
		$onto = create_triple ( $onto, $ptn, $rltp, $dss ) } @keys if @keys; # TODO test
	}
	#=============================================================================
# 	( keys %ptns != 0 ) ? return \%ptns : croak "No data to return!"; 
	return \%gns;
}

######################### idmapping ###########################################

sub parseIdMap {
	# no transcripts with multiple UPAC - data.log line 785
	# the file contains strictly 3 columns
	# returns a structure for the COMPLETE idmapping.dat !!!
	my (
	$self,
	$idmapping_path, # UniProt file idmapping.dat
	$mode,
	) = @_;

	$mode = 0;
	my %idmapping;
	my $FH = open_read ( $idmapping_path );
	while ( <$FH> ) {
		chomp;
		my ( $access, $db_name, $db_id ) = split /\t/;		
		if ( $mode == 1 ) {
			push @{ $idmapping{$db_name}{$access} }, $db_id;
		}elsif ( $mode == 2 ) {
			map { $idmapping{$db_name}{$_}{$access} = 1 } $db_id; # n:m 
		}else{
			push @{ $idmapping{$access}{$db_name} }, $db_id;
		}
	}
	close $FH;
	map { my $count = keys %{$idmapping{$_}}; print "idmapping: $_: $count\n";  } sort keys %idmapping if $mode;
	return \%idmapping;	
}
########################### filterByTaxa #######################################
sub filterByTaxa {
# 	shift @_;
	my (
	$self,
	$idmapping, # ouput of parseIdMap() mode '0'
	$taxid2taxlab, # hash
	$out_path, # string, optional
	) = @_;
	my %out;
	my $OUT;
	if ( $out_path ) {
		$OUT = open_write ( $out_path );
	}
	foreach my $upac ( keys %{$idmapping} ) {
		my $entry = $idmapping->{$upac};
		my $txn = $entry->{$txnk}[0];
		if ( $taxid2taxlab->{$txn} ) {
			$out{$upac} = $entry;
			if ( $out_path ) {
				foreach my $db ( keys %{$entry} ) {
					my $ids;
					map { $ids .= "$_\t" } @{$idmapping->{$upac}{$db}};
					chop $ids;
					print $OUT "$upac\t$db\t$ids\n";
				}
			}
		}
	}
	close $OUT if $out_path;
	return \%out;
}

######################## uniprot2rdf ###########################################
=head2 uniprot2rdf

  Usage    - 
  Returns  - 
  Args     - 
  Function - 
  
=cut
#vlmir
# Argumenents
# 1. output of parse()
# 2. Full path for writing RDF
# 3. ref to a hash of URIs (SharedVars::%uris)
#vlmir

sub uniprot2rdf {
	# Note: there may be multibple UP ID for a single UP AC !!!	
	# TODO relation names are still hard coded
	# able to handle multiple diseases
	my (
	$self,
	$data, # output from parse
	$rdf_file, 
	) = @_;
	croak "Not enough arguments!" if ( @_ < 2 );
	my $uris = \%uris;
	my $props = \%props;
	my $fs = '_';
	my $buffer = '';
	my $OUT = open_write ( $rdf_file );
	
	### Preambule of RDF file
	$buffer = write_rdf_preambule ( $uris,  );
	
	### Properties
	$buffer .= write_rdf_properties ( $uris, $props, \@rlskeys );

	$buffer .= <<BFR;
	<!--
	///////////////////////////////////////////////////////////////////////////////////////
	//
	// Classes
	//
	///////////////////////////////////////////////////////////////////////////////////////
	###
BFR
	print $OUT $buffer; $buffer = "";
	
	#-------------------------- disease -----------------------------------------
	# parent term
	# currently: http://purl.obolibrary.org/obo/OGMS_0000031
	my $dss_prn = $prns{'dss'}[0];
	$dss_prn =~ tr/:/_/;
	
	my $dsss = $data->{$dssk};
	foreach my $dsns ( keys %{$dsss} ) {
		foreach my $dsid ( keys %{$dsss->{$dsns}} ) {
			my $dss = $dsss->{$dsns}{$dsid};
			print $OUT  "\n### $uris->{'omim'}$dsid ###\n\n";
			print $OUT "\t<rdfs:Class rdf:about=\"&$dssns;$dsid\">\n";
			print $OUT "\t\t<rdfs:subClassOf rdf:resource=\"&obo;$dss_prn\"/>\n";
			# in case of mutiple names, though in practice there is only one
			map { print $OUT "\t\t<skos:prefLabel>".&char_http($_)."</skos:prefLabel>\n"; } keys %{$dss->{$nmk}};
			map { print $OUT "\t\t<skos:definition>".&char_http($_)."</skos:definition>\n" } keys %{$dss->{$defk}};
			
			my @upacs = keys %{$dss->{$ptnk}};
# 			map { print $OUT "\t\t<$ssbns:synonym>".&char_http($_)."</$ssbns:synonym>\n" } keys %{$dss->{$synk}};
			map { print $OUT "\t\t<skos:altLabel>".&char_http($_)."</skos:altLabel>\n" } keys %{$dss->{$synk}};
# 			print $OUT "\t\t<$ssbns:namespace>$dssns</$ssbns:namespace>\n";	
# 			print $OUT "\t\t<$ssbns:id>$dsid</$ssbns:id>\n";	
			
			print $OUT "\t</rdfs:Class>\n";
		}
	}
	
	#-------------------------- PTMs ---------------------------------------------
	
	## optional
	# parent class
	# currently http://purl.obolibrary.org/obo/PR_000025513 - 'modified amino-acid residue'
	my $ptm_prn = $prns{'ptm'}[0];
	$ptm_prn =~ tr/:/_/;

	my $ptms = $data->{'PTM'};
	foreach my $ptmk ( keys %{$ptms} ) { # currerntly only 'MOD'
		foreach my $id ( keys %{$ptms->{$ptmk}} ) { # bare MOD id
			my $ptm = $ptms->{$ptmk}{$id}; #print Dumper ( $ptm );
			my $rdf_id = "MOD_$id";
			my @syns = sort keys %{$ptm->{'Syn'}};
# 			my @acs = sort keys %{$ptm->{'AC'}};
			my ( $name ) = keys %{$ptm->{'Name'}};
			print $OUT  "\n### $uris->{'obo'}$rdf_id ###\n\n";
			print $OUT "\t<rdfs:Class rdf:about=\"&obo;$rdf_id\">\n";
			print $OUT "\t\t<rdfs:subClassOf rdf:resource=\"&obo;$ptm_prn\"/>\n";
			print $OUT "\t\t<skos:prefLabel>$name</skos:prefLabel>\n";
			map {print $OUT "\t\t<skos:prefLabel>$_</skos:prefLabel>\n"} @syns;
# 			my ( $NS, $id,  ) = @{$props{'ptn2ptm'}};
# 			map { print $OUT "\t\t<obo:$NS$fs$id rdf:resource=\"&uniprot;$_\"/>\n"; } sort keys %{$ptm->{'AC'}}; # not in APOs

			print $OUT "\t</rdfs:Class>\n"; # closed
		}
	}
	
	#--------------------------------------- proteins ----------------------------
	
	my $ptns = $data->{'Protein'}{$ptnk}; # all proteins
	my @upacs = keys %{$ptns};
	my $ptn_prn = $prns{'ptn'}[0];
	$ptn_prn =~ tr/:/_/;
	
	foreach my $upac ( @upacs ) {
		my $ptn =  $ptns->{$upac};
		print $OUT  "\n### $uris->{'uniprot'}$upac ###\n\n";	
		print $OUT "\t<rdfs:Class rdf:about=\"&$ptnns;$upac\">\n";		
		print $OUT "\t\t<rdfs:subClassOf rdf:resource=\"&sio;$ptn_prn\"/>\n";
		my $NS;
		my ( $id ) = %{$ptn->{'ID'}};
		print $OUT "\t\t<skos:prefLabel>".&char_http($id)."</skos:prefLabel>\n";
		my ( $definition ) = %{$ptn->{$defk}};
		print $OUT "\t\t<skos:definition>".&char_http($definition)."</skos:definition>\n" if $definition;
		
		#--------------------- taxon -----------------------------------
		my @txns = sort keys %{$ptn->{$txnk}};
		my $taxon = $txns[0];
		( $NS, $id ) = @{$props{'ptn2txn'}};
		
		print $OUT "\t\t<obo:$NS$fs$id rdf:resource=\"&obo;$TXNNS$fs$taxon\"/>\n";
		
		#----------------------- gene ids ------------------------------
		my @gene_ids = keys %{$ptn->{$gnk}};
		( $NS, $id ) = @{$props{'gn2gp'}};
		map { print $OUT "\t\t<sio:$NS$fs$id rdf:resource=\"&$gnns;$_\"/>\n"; } @gene_ids;
		
		#-------------------------- disease ----------------------------
		my @dssnss = keys %{$ptn->{$dssk}};
		( $NS, $id ) = @{$props{'ptn2dss'}};
		map { print $OUT "\t\t<obo:$NS$fs$id rdf:resource=\"&$dssns;$_\"/>\n" } map {sort keys %{$ptn->{$dssk}{$_}}} @dssnss;
		
		#-------------------------- PTMs -------------------------------
		
		( $NS, $id ) = @{$props{'ptn2ptm'}};
		map { print $OUT "\t\t<obo:$NS$fs$id rdf:resource=\"&obo;MOD_$_\"/>\n"; } sort keys %{$ptn->{'MOD'}}; # bare MOD ids
		
		#---------------------- synonyms -------------------------------
		my @syns = keys %{$ptn->{$synk}};
		foreach my $syn (@syns){
			print $OUT "\t\t<skos:altLabel>".&char_http($syn)."</skos:altLabel>\n";
		}
		
		#---------------------------- xrefs ----------------------------
		map { print $OUT "\t\t<skos:relatedMatch>$nss{insdc}:$_</skos:relatedMatch>\n" } keys %{$ptn->{$xrfk}};

		print $OUT "\t</rdfs:Class>\n"; # closed
	}
	
	print $OUT "</rdf:RDF>\n\n";
	print $OUT "<!--Generated with: ".$0.", ".__date."###\n";
	close $OUT;
}

sub uniprot2ttl {
	# Note: there may be multibple UP ID for a single UP AC !!!	
	# TODO relation names are still hard coded
	# able to handle multiple diseases
	my (
	$self,
	$data, # output from parse
	$ttl_file, 
	) = @_;
	croak "Not enough arguments!" if ( @_ < 2 );
	my $uris = \%uris;
	my $props = \%props;
	my $fs = '_';
	my $buffer = '';
	my $OUT = open_write ( $ttl_file );
	
	### Preambule of RDF file ###
	$buffer = write_ttl_preambule ( $uris,  );	
	### Properties ###
	$buffer .= write_ttl_properties ( $uris, $props, \@rlskeys );	
	print $OUT $buffer; $buffer = "";

	### Classes ###
	my $s = " ;\n\t";
	my $sp = " ,\n\t\t";
	#-------------------------- disease -----------------------------------------
	# parent term
	my $dss_prn = $prns{'dss'}[0];
	$dss_prn =~ tr/:/_/;
	my ( @keys, $first );
	my $dsss = $data->{$dssk};
	foreach my $dsns ( keys %{$dsss} ) {
		foreach my $dsid ( keys %{$dsss->{$dsns}} ) {
			my $dss = $dsss->{$dsns}{$dsid};
			print $OUT  "\n### $uris->{'omim'}$dsid ###\n";
			print $OUT "\n$dssns:$dsid rdfs:subClassOf rdfs:Class";
			print $OUT $sp."obo:$dss_prn";
			## Note: currently multiple names and defs do occur !!
			@keys = sort keys %{$dss->{$nmk}}; $first = shift @keys;
			print $OUT $s."skos:prefLabel \"".&char_http($first)."\"";
			my $flag = 1;
			$first = shift @keys;
			if ( $first ) {
				$flag = 0;
				print $OUT $s."skos:altLabel \"".&char_http($first)."\"";
			}
			map { print $OUT $sp."\"".&char_http($_)."\""; } @keys;
			@keys = sort keys %{$dss->{$synk}};
			if ( $flag ) {
				$first = shift @keys;
				print $OUT $s."skos:altLabel \"".&char_http($first)."\"";
			}
			map { print $OUT $sp."\"".&char_http($_)."\"" } @keys;
			
			@keys = sort keys %{$dss->{$defk}};
			my @defs = map { &char_http($_) } @keys;
			my $defs = join ( '; ', @defs );
			print $OUT $s."skos:definition \"$defs\"";
			print $OUT " .\n";
		}
	}
	
	#-------------------------- PTMs ---------------------------------------------
	
	## optional
	# parent class
	# currently http://purl.obolibrary.org/obo/PR_000025513 - 'modified amino-acid residue'
	my $ptm_prn = $prns{'ptm'}[0];
	$ptm_prn =~ tr/:/_/;

	my $ptms = $data->{'PTM'};
	foreach my $ptmk ( keys %{$ptms} ) { # currerntly only 'MOD'
		foreach my $id ( keys %{$ptms->{$ptmk}} ) { # bare MOD id
			my $ptm = $ptms->{$ptmk}{$id}; #print Dumper ( $ptm );
			my $rdf_id = "MOD_$id";
			my ( $name ) = keys %{$ptm->{'Name'}};
			print $OUT  "\n### $uris->{'obo'}$rdf_id ###\n\n";
			print $OUT "obo:$rdf_id rdfs:subClassOf rdfs:Class";
			print $OUT $s."rdfs:subClassOf obo:$ptm_prn";
			print $OUT $s."skos:prefLabel \"$name\"";
			my @syns = sort keys %{$ptm->{'Syn'}};
			my $first = shift @syns;
			print $OUT $s."skos:altfLabel \"$first\"" if $first;
			map {print $OUT $sp."\"$_\""} @syns;
			print $OUT " .\n";
		}
	}
	
	#--------------------------------------- proteins ----------------------------
	
	my $ptns = $data->{'Protein'}{$ptnk}; # all proteins
	my @upacs = keys %{$ptns};
	my $ptn_prn = $prns{'ptn'}[0];
	$ptn_prn =~ tr/:/_/;
	
	foreach my $upac ( @upacs ) {
		my $ptn =  $ptns->{$upac};
		print $OUT  "\n### $uris->{'uniprot'}$upac ###\n\n";	
		print $OUT "$ptnns:$upac rdfs:subClassOf rdfs:Class";		
		print $OUT $s."rdfs:subClassOf sio:$ptn_prn";
		my $NS;
		my ( $id ) = %{$ptn->{'ID'}};
		print $OUT $s."skos:prefLabel \"".&char_http($id).'"';
		my ( $definition ) = %{$ptn->{$defk}};
		print $OUT $s."skos:definition \"".&char_http($definition)."\"" if $definition;
		
		#--------------------- taxon -----------------------------------
		my @txns = sort keys %{$ptn->{$txnk}};
		my $taxon = $txns[0]; # asuming a single taxon
		( $NS, $id ) = @{$props{'ptn2txn'}};
		print $OUT $s."obo:$NS$fs$id obo:$TXNNS$fs$taxon";
		
		#----------------------- gene ids ------------------------------
		( $NS, $id ) = @{$props{'gn2gp'}};
		@keys = sort keys %{$ptn->{$gnk}};
		$first = shift @keys;
		print $OUT $s."sio:$NS$fs$id $gnns:$first" if $first;
		map { print $OUT $sp."$gnns:$_"; } @keys;
		
		#-------------------------- disease ----------------------------
		( $NS, $id ) = @{$props{'ptn2dss'}};
		@keys = sort keys %{$ptn->{$dssk}{MIM}};
		$first = shift @keys;
		print $OUT $s."obo:$NS$fs$id $dssns:$first" if $first;
		map { print $OUT $sp."$dssns:$_" } @keys;
		
		#-------------------------- PTMs -------------------------------
		
		( $NS, $id ) = @{$props{'ptn2ptm'}};
		@keys = sort keys %{$ptn->{'MOD'}}; # bare MOD ids
		$first = shift @keys;
		print $OUT $s."obo:$NS$fs$id obo:MOD_$first" if $first;
		map { print $OUT $sp."obo:MOD_$_"; } @keys;
		
		#---------------------- synonyms -------------------------------
		@keys = sort keys %{$ptn->{$synk}};
		$first = shift @keys;
		print $OUT $s."skos:altLabel \"".&char_http($first).'"' if $first;
		map { print $OUT $sp."\"".&char_http($_).'"' } @keys;
		
		#---------------------------- xrefs ----------------------------
		
		@keys = sort keys %{$ptn->{$xrfk}};
		$first = shift @keys;
		print $OUT $sp."skos:relatedMatch>$nss{insdc}:$first" if $first;
		map { print $OUT $sp."skos:relatedMatch>$nss{insdc}:$_" } @keys;
		
		print $OUT " .\n";
	}
	
	print $OUT "\n### Generated with: ".$0.", ".__date."###\n";
	close $OUT;
}

## not used 2015-05-28
# sub _get_value {
# 	my ( $line ) = @_;
# 	my ( $head, $value ) = split /=/, $line;
# 	chop $value if substr $value, -1 eq ';';
# 	return $value;
# }

sub _parse_cc {
# parses a block of lines CC
# the lines in the block don't have the leading 5 chars (e.g. 'FT   ') of the data file
# TODO generalise to process any number of sub-fields (not only 1)
	my (
	$lines,
	$key,
	) = @_;
	my $data = {};
	my (  $text );
	foreach my $line ( @{$lines} ) {
		if ( $line =~ $rex_cc ) {
			push @{$data->{$key}}, $text if $text;			
			if ( $1 eq $key ) {
				(  $text ) = ( $2);
			} else {
				(  $text ) = (  '' );
			}
		}
		elsif ( $text ) {
			my $substr = substr $line, 4;
			$substr ? $text .= ' ' . $substr : print "CC: $line\n"; # clean
		}
	}
	push @{$data->{$key}}, $text if $key && $text; # flushing
	return $data;
}

sub _parse_ft {
# parses a block of lines FT
# the lines in the block don't have the leading 5 chars (e.g. 'FT   ') of the data file
# TODO generalise to process any number of sub-fields (not only 1)
	my (
	$lines, # ref to an array of FT lines
	$key, # string, e.g. 'MOD_RES'
	) = @_;
	my $data = {};
	my ( $text );
	foreach my $line ( @{$lines} ) {
# my $rex_ft = qr/^(\w+)\s+(\d+)\s+(\d+)\s{7}(.+)/xmso; # matches the first line of a sub-block; TODO refine
		if ( my @fields = $line =~ $rex_ft ) { # doesn't match lines without text field, e.g.'HELIX' lines
# 		print "fields: $fields[0], $fields[1], $fields[2], $fields[3], \n";
			push @{$data->{$key}}, $text if $text;
			
			if ( $1 eq $key ) { # the first line of the sub-block
				( $text ) = ( $4 );
			} else { # the first line of the next sub-block
				( $text ) = ( '' );
			}
		}	elsif ( $text ) { # one of the extra lines
# my $rex_ex_ln = qr/^\s+(\S+.*)$/xmso;
			if ( $line =~ $rex_ex_ln ) { # skpping lines without text field, e.g.'HELIX' lines
				$text .= ' ' . $1;
			} else {
			}
		}
	}
	push @{$data->{$key}}, $text if $key && $text; # flushing
	return $data;
}

## Not used 2015-05-28
# sub parse_block {
# # Note: this sub si buggy, see _parse_cc and _parse_ft TODO fix it
# # parses a block of lines with the same primary key (e.g. FT)
# # the lines in the block don't have the leading 5 chars (e.g. 'FT   ') of the data file
# 	my (
# 	$lines,
# 	$regex,
# 	$offset,
# 	$delimiter, # optional
# 	) = @_;
# 	$delimiter ||= '';
# 	my $data = {};
# 	my ( $key, $text );
# 	foreach my $line ( @{$lines} ) {
# 		if ( $key and ($line =~ $regex) ) { # next block
# 			push @{$data->{$key}}, $text;
# 			$key = $1; # new SECONDARY key, e.g. MOD_RES
# 			$text = $2;
# 		} elsif ( $1 ) { # the first CC line
# 			$key = $1;
# 			$text = $2;
# 		} else { # another line in the block
# # 			my $substr = substr $line, $offset; # too many line formats
# 			my $rex_new_line = qr/^\s{$offset}(.*)$/xmso;	# Not used
# 			$1 ? $text .= $delimiter.$1 : next; # e.g. skipping lines containing only positions, like HELIX lines
# 		}
# 	} # end of line
# 	push @{$data->{$key}}, $text if $key && $text; # the last block TODO why missing values $key - likely solved
# 	return $data;
# }

## Not used 2015-05-28
# sub trim_string {
# 	my ( $string, $last_char ) = @_;
# 	chop $string if (substr ( $string, -1 ) eq $last_char );
# 	return $string;
# }

## Not used 2015-05-28, though tested
sub get_fasta {
	my (
	$self,
	$in_file, 
	$out_file,
	$min_length,
	$map, # optional
	) = @_;
	my $IN = open_read ( $in_file );
	my $OUT = open_write ( $out_file );
	my $short_ptns;
	my %ac2id;
	local $/ = "\n//\n";
	while (<$IN>) {
		chomp;
# 		my ( $seq_lng, $seq ) = $_ =~ $rex_seq;
		next unless my ( $seq_lng, $seq ) = $_ =~ $rex_seq; # TODO test
# 		my ( $ac ) = $_ =~ $rex_ac;
		next unless my ( $ac ) = $_ =~ $rex_ac; # TODO test
		if ( $map ) {
			next unless $map->{$ac};
		}
		if ( $seq_lng < $min_length) {
			$short_ptns->{$ac} = $seq;
			next
		}
		next unless my ( $id,  ) = $_ =~ $rex_id; # TODO test
		next unless my ( $tx ) = $_ =~ $rex_tx; # TODO test
		$seq =~ s/\s//xmsg;
		$columns = 60; # line length to output
		$seq = wrap ( '', '', ($seq) ); # ( 1st line indent, indent, @lines )
		print $OUT ">$tx|$ac|$id|$seq_lng\n$seq\n";
		$ac2id{$ac} = $id;
	} # end of while
# 	return \%ac2id;
	return $short_ptns;
}

## Not used 2015-05-28, though tested
sub filter_dat {
	my (
	$self,
	$infiles, # ref to an array of data file full paths
	$out_file_path, # UniProt .dat file
	$taxon, # NCBI_TaxID
	$map, # ref { UPAC=>UPID ) for filtering, optional
	) = @_;
	my $DAT = open_write ( $out_file_path );
	my %seen;
# DE   Flags: Precursor; Fragment;
# DE   Flags: Fragment;
# DE   Flags: Precursor; Fragments;
	my $rex_frg = qr/^DE\s{3}Flags:\s.*?Fragment.*?$/xmso; # should stay here
	foreach my $in_file ( @{$infiles} ) {
		my $IN = open_read ( $in_file );
		local $/ = "\n//\n";
		# TODO test the new regexes
# 		my $rex_ac = qr/^AC\s{3}(\w+)/xmso; # matches only the first AC
		while (<$IN>) {
			my $entry = $_;
# 			if ( /^OX\s+NCBI_TaxID=$taxon;/xms) {
			my ( $tx ) = $entry =~ $rex_tx;# global regex;
			if ( $tx == $taxon ) {
				next unless my ( $ac ) = $entry =~ $rex_ac; # global regex # TODO test
				next unless my ( $id ) = $entry =~ $rex_id; # global regex # TODO test
				if ( $map ) {
					next unless $map->{$ac};
				}
				next if $entry =~ $rex_frg; # TODO to be tested
				next if $seen{$ac}; # a second entry with the same AC (happens)
				$seen{$ac} = $id;
				print $DAT "$entry";
			}
		}		
	}
	close $DAT;
	return \%seen;
}

1;
