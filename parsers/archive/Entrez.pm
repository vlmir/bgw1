
package parsers::Entrez;

# !!! With the complete NCBI data the resulitng data structure is about 120G !!!

use strict;
use warnings;
use Carp;

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};
use auxmod::SharedSubs qw( 
char_http
__date
test_prns
add_new_term
retrieve_term
open_read
open_write
write_ttl_preambule
write_ttl_properties
create_triple
set_props
);
use auxmod::SharedVars qw( 
%nss
%props
%prns
%uris
);


my $GNNS = $nss{'gn'};
my $PRTNS = $nss{'ptn'};
my $TXNNS = $nss{'txn'};

my $gnns = lc $GNNS;
my $ptnns = lc $PRTNS;

# shared keys in the data structures ( all arbitrary )
# intended to be used as annotatin properties in RDF
my $txnk = 'taxonId'; # 0 - no missing values
my $gnk = 'geneId'; # 1 - unique
my $symbk = 'symbol'; # 2 - no missing values; NOT unique !!!
my $lctgk = 'locusTag'; # 3 - unique but there are missing values
my $synmk = 'synonym'; # 4 - multiple
my $dbk = 'dbXref'; # 5 - multiple
my $chrmk = 'chromosome'; # 6
my $mplck = 'mapLocation'; # 7
my $dscrk = 'description'; # 8 - mess, should not be used
my $gntpk = 'geneType'; # 9 - no missing values
my $gnnmk = 'geneName'; # 10 single value
my $flnmk = 'fullName'; # 11 single value

my $rnak = 'rnaAc'; # 3; many lines with missing values ('-')
my $rnagik = 'rnaGi'; # 4; many lines with missing values ('-')
my $ptnk = 'proteinAc'; # 5
my $ptngik = 'proteinGi'; # 6
my $gnmack = 'genomeAc'; # 7; many lines with missing values ('-')
my $gnmgik = 'genomeGi'; # 8; many lines with missing values ('-')
my $gnstrk = 'geneStart'; # 9; many lines with missing values ('-')
my $gnendk = 'geneEnd'; # 10; many lines with missing values ('-')
my $ornk = 'orientation'; # 11; values: '+', '-', '?'; the meaning of '-' is different !!!
my $upack = 'UniProtAc';

my $engnk = 'ensemblGeneId'; # 2
my $enrnak = 'ensemblRnaId'; # 4
my $enptnk = 'ensemblProtId'; # 6

my @rlskeys = ( 'gn2txn', 'gn2gp' );
############################# new ##############################################
sub new {
	my $class = shift;
	my $self = {};
	bless ( $self, $class );
	return $self;
}


######################## parse_genes ###########################################

# TODO find out what Start and End refer to
sub parse_genes {
# the filtering by taxa should be done beforehand both for BGW and APOs
# more specific filtering is perfomed by the downstrean functions (different for BGW and APOs)
# TODO refine the parsing - split if necessary the bottom level hashes and replace them with arrays ?
# TODO root out superfleous fields
	# Note: multiple lines for a gene, pobably multiple genome assemblies - don't see this anymore
		
	my (
	$self,
	$file,
	$map, # optional
	) = @_;
	my $data;
	my $IN = open_read ( $file );
	while ( <$IN> ) {
		next if substr ( $_, 0, 1) eq "\n";
		next if substr ( $_, 0, 1) eq "#";
		chomp;
		my @vals = split /\t/;
		my $gnid = $vals[1];
		
		if ( $map ) { next unless $map->{$gnid} }
		my $txnid = $vals[0];
		$data->{'GENES'}{$gnk}{$gnid}{$txnk}{$txnid}++;
		$data->{'GENES'}{$gnk}{$gnid}{$symbk}{$vals[2]}++;
		$data->{'GENES'}{$gnk}{$gnid}{$lctgk}{$vals[3]}++;
		# synonyms
		my @syns = split /\|/, $vals[4];
		map { $data->{'GENES'}{$gnk}{$gnid}{$synmk}{$_}++ } @syns;
		# dbxrefs
		my @dbxrefs = split /\|/, $vals[5];
		map { $data->{'GENES'}{$gnk}{$gnid}{$dbk}{$_}++ } @dbxrefs;
# 		$data->{'GENES'}{$gnk}{$gnid}{$dbk}{$vals[5]}++;
		$data->{'GENES'}{$gnk}{$gnid}{$chrmk}{$vals[6]}++;
		$data->{'GENES'}{$gnk}{$gnid}{$mplck}{$vals[7]}++;
		$data->{'GENES'}{$gnk}{$gnid}{$dscrk}{$vals[8]}++; # to be eliminated
		$data->{'GENES'}{$gnk}{$gnid}{$gntpk}{$vals[9]}++;
		$data->{'GENES'}{$gnk}{$gnid}{$gnnmk}{$vals[10]}++;
		$data->{'GENES'}{$gnk}{$gnid}{$flnmk}{$vals[11]}++;
		$data->{'TAXA'}{$txnk}{$txnid}{$gnk}{$gnid}++;
		# to be used in entrez2onto; will be redefind by other functions
# 		$data->{'GENES'}{$gnk}{$gnid}{$upack} = \@upacs;
# 		} # end of if
	} # end of while
# 	( keys %{$data} ) > 0 ? return $data : carp "No data to return: $!";
	$data->{'GENES'} ? return $data : carp "No data to return: $!";
}

sub parse_accs {
	# Note: multiple lines for a gene
	# apparently lines are protein based (many lines have no rna acc)
	# UP ACs seem to be included in the field with protein accesions (ind 5) !!!
	# TODO move the handling of MOD to entrez2onto() and entrez2rdf()
	my $self = shift;
	my (
	$file,
	$data,
	$map, # ref to a hash {ncbiGeneID=> [UpProtAc]) # TODO update the code accordingly !!! (optional)
	) = @_;
	
	my $IN = open_read ( $file );
	while ( <$IN> ) {
		next if substr ( $_, 0, 1) eq "\n";
		next if substr ( $_, 0, 1) eq "#";
		chomp;			
		my @vals = split /\t/;
		my $txnid = $vals[0];
		my $gnid = $vals[1];
		#~ my $rnaid = $vals[3];
		my $rnaid = substr $vals[3], 0, -2; # stripping the version
		#~ my $ptnid = $vals[5];
		my $ptnid = substr $vals[5], 0, -2; # stripping the version
		my $gnmid = $vals[7];
		my $gnstr = $vals[9];
		my $gnend = $vals[10];
		my $orn = $vals[11];
		
		$data->{'GENES'}{$gnk}{$gnid}{$ptnk}{$ptnid}++;
		$data->{'GENES'}{$gnk}{$gnid}{$ptngik}{$vals[6]}++;
		$data->{'GENES'}{$gnk}{$gnid}{$gnstrk}{$gnstr}++ unless $gnstr eq '-';
		$data->{'GENES'}{$gnk}{$gnid}{$gnendk}{$gnend}++ unless $gnend eq '-';
		$data->{'GENES'}{$gnk}{$gnid}{$ornk}{$orn}++ unless $orn eq '?';
		if ( $rnaid ) {
			$data->{'TAXA'}{$txnk}{$txnid}{$rnak}{$rnaid}++;
			$data->{'GENES'}{$gnk}{$gnid}{$rnak}{$rnaid}++;
			$data->{'GENES'}{$gnk}{$gnid}{$rnagik}{$vals[4]}++;
			$data->{'RNAS'}{$rnak}{$rnaid}{$txnk}{$txnid}++;
			$data->{'RNAS'}{$rnak}{$rnaid}{$gnk}{$gnid}++;
			$data->{'RNAS'}{$rnak}{$rnaid}{$rnagik}{$vals[4]}++;
			$data->{'RNAS'}{$rnak}{$rnaid}{$ptnk}{$ptnid}++;
			$data->{'RNAS'}{$rnak}{$rnaid}{$ptngik}{$vals[6]}++;
			$data->{'PROTS'}{$ptnk}{$ptnid}{$rnak}{$rnaid}++;
			$data->{'PROTS'}{$ptnk}{$ptnid}{$rnagik}{$vals[4]}++;
		}
		
		if ( $gnmid ne '-' ) {
			$data->{'GENES'}{$gnk}{$gnid}{$gnmack}{$gnmid}++;
			$data->{'GENES'}{$gnk}{$gnid}{$gnmgik}{$vals[8]}++;
		}
		
		$data->{'TAXA'}{$txnk}{$txnid}{$ptnk}{$ptnid}++;
		$data->{'PROTS'}{$ptnk}{$ptnid}{$txnk}{$txnid}++;
		$data->{'PROTS'}{$ptnk}{$ptnid}{$gnk}{$gnid}++;
		$data->{'PROTS'}{$ptnk}{$ptnid}{$ptngik}{$vals[6]}++;
		
		if ( $map ) {
# 		my $upac = $map->{$gnid};
			next unless $map->{$gnid};
			next unless my @upaccs = @{$map->{$gnid}};
			foreach my $upac ( @upaccs ) {
	# 		if ( $upac ) {
				$data->{'GENES'}{$gnk}{$gnid}{$upack}{$upac}++; # TODO fix this
				$data->{'RNAS'}{$rnak}{$rnaid}{$upack}{$upac}++ if $rnaid;
				$data->{'PROTS'}{$ptnk}{$ptnid}{$upack}{$upac}++;
				$data->{'UNIPROT'}{$upack}{$upac}{$gnk}{$gnid}++;
				$data->{'UNIPROT'}{$upack}{$upac}{$rnak}{$rnaid}++ if $rnaid;
				$data->{'UNIPROT'}{$upack}{$upac}{$ptnk}{$ptnid}++;
	# 		}
# 			else { $data->{'LOG'}{'noUpAc'}{$ptnid}++; }
			}
		}
	}
	return $data;
}

# fields of interest, origin at '0'
#~ my $engnk = 'ensemblGeneId'; # 2
#~ my $rnak = 'rnaAc'; # 3
#~ my $enrnak = 'ensemblRnaId'; # 4
#~ my $ptnk = 'proteinAc'; # 5
#~ my $enptnk = 'ensemblProtId'; # 6
sub parse_ensembl {
	# Note: multiple lines for a gene
	# apparently lines are rna based
	my $self = shift;
	my (
	$file,
	$data,
	) = @_;

	my $IN = open_read ( $file );
	while ( <$IN> ) {
		next if substr ( $_, 0, 1) eq "\n";
		next if substr ( $_, 0, 1) eq "#";
		chomp;			
		my @vals = split /\t/;
		my $txnid = $vals[0];
		my $gnid = $vals[1];
		my $engnid = $vals[2];
		#~ my $rnaid = $vals[3];
		my $rnaid = substr $vals[3], 0, -2; # stripping the version
		my $enrnaid = $vals[4];
		#~ my $ptnid = $vals[5];
		my $ptnid = substr $vals[5], 0, -2; # stripping the version
		my $enptnid = $vals[6];
		$data->{'GENES'}{$gnk}{$gnid}{$engnk}{$engnid}++;
		$data->{'GENES'}{$gnk}{$gnid}{$enrnak}{$enrnaid}++;
		$data->{'GENES'}{$gnk}{$gnid}{$enptnk}{$enptnid}++;
		$data->{'RNAS'}{$rnak}{$rnaid}{$engnk}{$engnid}++;
		$data->{'RNAS'}{$rnak}{$rnaid}{$enrnak}{$enrnaid}++;
		$data->{'RNAS'}{$rnak}{$rnaid}{$enptnk}{$enptnid}++;
		$data->{'PROTS'}{$ptnk}{$ptnid}{$engnk}{$engnid}++;
		$data->{'PROTS'}{$ptnk}{$ptnid}{$enrnak}{$enrnaid}++;
		$data->{'PROTS'}{$ptnk}{$ptnid}{$enptnk}{$enptnid}++;
	}
	return $data;
}

######################### entrez2onto ##########################################

sub entrez2onto {
# no genes yet in the input ontology
	my ( 
	$self,
	$onto,
	$data, # output from parse_genes
	$map, # {GeneID => [UPACs]}; mandatory for making rels
	) = @_;
	#------------------------- PREAMBULE -----------------------------------------
	# setting rels in the onto 
	
	my $tpdefs = set_props ( $onto, \%props, \@rlskeys );

	# testing the parent terms in the ontology
	my $parents = test_prns ( $onto, \%prns );
	my @gnprns = ( $parents->{'gn'} );
	# hashes to collect terms
	my %genes; # Gene term ID => gene term
	
	my $fs = ':';
	my $onto_name = $onto-> name();
	#============================== genes ========================================
	foreach my $id ( sort keys %{$data->{'GENES'}{$gnk} }) {# bare NCBI id
# 		next unless my @upacs = @{$map-> {$id}}; # the hash is need but the filtering is better done in parse_genes
		next unless $map-> {$id}; # the hash is needed though the filtering is better done in parse_genes
		my $gntmid = $GNNS.$fs.$id;
		my $gene = add_new_term ( $onto, $gntmid, \@gnprns, \%genes);
		my $gndata = $data->{'GENES'}{$gnk}{$id}; # ref to a hash
		#--------------------------- single values:---------------------------------
		# declared as such in READMY
		# 'map' function is used below just to extract the only value
		my @symbols =  keys %{$gndata->{$symbk}}; # the only key, no missing values
		my $symbol = shift @symbols; # nevertheless a limited number of genes have piped values!!!
		my $name;
		map { $_ ne '-' ? $name = $_ : $name = $symbol; } keys %{$gndata->{$gnnmk}}; # a single key
		$gene-> name ( $name );
		my $def;
		map { $def = "The $_ gene $name"; } keys %{$gndata->{$gntpk}}; # safe
		map { $def .= " ($_)" if $_ ne '-'; } keys %{$gndata->{$flnmk}};
		map { $def .= " located on the chromosome $_" if $_ ne '-'; } keys %{$gndata->{$chrmk}};
		map { $def .= " mapped at $_" if $_ ne '-'; } keys %{$gndata->{$mplck}};
		$def .= '.';
		$gene->def_as_string ( $def, "$onto_name:team" );
		#------------------------ multiple values ----------------------------------
		# declared as such in README, have been split on '|' in parse_genes()
		map { $gene->synonym_as_string ( $_, "[]", 'EXACT' ) if $_ ne '-'; } keys %{$gndata->{$synmk}};
		map { $gene->xref_set_as_string ( "[$_]" ) if $_ ne '-'; } keys %{$gndata->{$dbk}};
		
		#----------------------------- relations -----------------------------------
		my @ids = keys %{$gndata->{$txnk}}; # NCBI taxon IDs, single element
		my $txtmid = $TXNNS.$fs.$ids[0];
		my $taxon = $onto-> get_term_by_id ( $txtmid );
		if ( ! $taxon ) {
			carp "Term: $txtmid not found in ontology: $onto"; # means mismatch UP<->NCBI
			next;
		}
		my $rltp;
		$rltp = $tpdefs->{'gn2txn'};
		$onto = create_triple ( $onto, $gene, $rltp, $taxon );
		$rltp = $tpdefs->{'gn2gp'};
		# 'if $ptn' below is necessary - @upacs may contain proteins not present in $onto (from idmapping file) - NOT anymore;
		map {my $ptn = $onto-> get_term_by_id ( $PRTNS.$fs.$_); $onto = create_triple ( $onto, $gene, $rltp, $ptn ) if $ptn} @{$map-> {$id}};
	} # end of foreach gene_id
	#=============================================================================
	( keys %genes ) > 0 ? return \%genes : carp "No genes to return !";
}


sub entrez2ttl{
	my (
	$self,
	$data, # output from parse_entrez
# 	$map, # mandatory,  # [gnid => [upacs]}
	$out_path, 
	) = @_;
	croak "Not enough arguments!" if ( @_ < 3 );
		
	my $uris = \%uris;
	my $props = \%props;
	my $fs = '_';
	my $buffer = '';
	my $OUT = open_write ( $out_path );
	
	### Preambule of RDF file ###
	$buffer = write_ttl_preambule ( $uris,  );	
	### Properties ###
	$buffer .= write_ttl_properties ( $uris, $props, \@rlskeys );	
	print $OUT $buffer; $buffer = "";

	### Classes ###
	my $s = " ;\n\t";
	my $sp = " ,\n\t\t";
	my $gn_prn = $prns{'gn'}[0];
	$gn_prn =~ tr/:/_/;

	foreach my $gnid ( sort keys %{$data->{'GENES'}{$gnk}} ) {
		my $gn = $data->{'GENES'}{$gnk}{$gnid};
		my ( @keys, $first );
		print $OUT  "\n### $uris->{'ncbigene'}$gnid ###\n";
		print $OUT "\n$gnns:$gnid a rdfs:Class";
		print $OUT $s."rdfs:subClassOf sio:$gn_prn"; # TODO extract namespaces (e.g. 'sio') from IDs
		@keys = sort keys %{$gn->{$symbk}}; $first = shift @keys;
		print $OUT $s."skos:prefLabel \"".&char_http($first)."\"" if $first;
		carp "Extra symbols for gene $gnid: @keys" if @keys;
# 		map { print $OUT $sp."skos:prefLabel \"".&char_http($_)."\"";} @keys;
		
		@keys = sort keys %{$gn->{$dscrk}}; $first = shift @keys;
		print $OUT $s."skos:definition \"".&char_http($first)."\"" if $first;
		carp "Extra defs for gene $gnid: @keys" if @keys;
# 		map { print $OUT $sp."skos:definition \"".&char_http($_)."\"";} @keys;
		
		my ( $NS, $id ) = @{$props{'gn2txn'}};
		@keys = sort { $a <=> $b } keys %{$gn->{$txnk}}; $first = shift @keys;
		print $OUT $s."obo:$NS$fs$id obo:$TXNNS$fs$first" if $first;
		carp "Extra taxa for gene $gnid: @keys" if @keys;
# 		map  { print $OUT $sp."obo:$NS$fs$id obo:$TXNNS$fs$_/";} @keys;
		
		( $NS, $id ) = @{$props{'gn2gp'}};
		@keys = sort keys %{$gn->{$upack}}; $first = shift @keys;
		print $OUT $s.lc($NS).":$NS$fs$id uniprot:$first" if $first;
		map  { print $OUT $sp."uniprot:$_";} @keys;
		
		## &char_http is needed because of synonyms like p34<CDC2> 
		@keys = sort keys %{$gn->{$synmk}}; $first = shift @keys;
		print $OUT $s."skos:altLabel \"".&char_http($first)."\"" if $first ne '-';
		map { print $OUT $sp."\"".&char_http($_)."\"" if $_ ne '-'; } @keys;
		
		@keys = sort keys %{$gn->{$engnk}}; $first = shift @keys;
		print $OUT $s."skos:relatedMatch \"$nss{ens}:$first\"" if $first ne '-';
		map { print $OUT $sp."\"$nss{ens}:$_\"" if $_ ne '-'; } @keys;
		
		# the code below retrieves all annotations as data properties; currently only ENSEMBL used
# 		my %select_keys = ( $engnk => 1, );
# 		foreach my $key ( sort keys %{$gn} ) {
# 			next unless $select_keys{$key};
# 			my $vals = $gn->{$key};
# 			#~ map { print $OUT $sp."ssb:$key>$_</ssb:$key"; } sort keys %{$vals};
# 			map { print $OUT $sp."ssb:$key>$_</ssb:$key>\n" if $_ ne '-'; } sort keys %{$vals}; # TODO get rid of 'ssb'
# 		}
	}
	print $OUT " .\n";
	print $OUT "\n### Generated with: $0, ".__date." ###\n";
	
	close $OUT;
}

1;
