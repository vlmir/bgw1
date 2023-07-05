#! /usr/bin/perl
package parsers::Entrez;

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
	$Carp::Verbose = 1;
	use Data::Dumper;
};
# !!! With the complete NCBI data the resulitng data structure is about 120G !!!

use auxmod::SharedSubs qw( 
char_http
__date
open_read
open_write
write_ttl_preambule
write_ttl_properties
);
use auxmod::SharedVars qw( 
%nss
%props
%prns
%uris
);


my $GNNS = $nss{'gn'};
my $PRTNS = $nss{'tlp'};
my $TXNNS = $nss{'txn'};

my $gnns = lc $GNNS;
my $tlpns = lc $PRTNS;

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
my $tlpk = 'proteinAc'; # 5
my $tlpgik = 'proteinGi'; # 6
my $gnmack = 'genomeAc'; # 7; many lines with missing values ('-')
my $gnmgik = 'genomeGi'; # 8; many lines with missing values ('-')
my $gnstrk = 'geneStart'; # 9; many lines with missing values ('-')
my $gnendk = 'geneEnd'; # 10; many lines with missing values ('-')
my $ornk = 'orientation'; # 11; values: '+', '-', '?'; the meaning of '-' is different !!!
my $upack = 'UniProtAc';

my $engnk = 'ensemblGeneId'; # 2
my $enrnak = 'ensemblRnaId'; # 4
my $entlpk = 'ensemblProtId'; # 6

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
	$data_path,
	$map, # optional
	) = @_;
	my $data;
	my $IN = open_read ( $data_path );
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
	my @chunks = split /\./, $data_path;
	pop @chunks;
	my $path = join '.', @chunks;
	my $json_path = $path . '.json';
	my $var = encode_json $data;
	my $OUT = open_write ( $path . '.json' );
	print $OUT $var;
	close $OUT;
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
		#~ my $tlpid = $vals[5];
		my $tlpid = substr $vals[5], 0, -2; # stripping the version
		my $gnmid = $vals[7];
		my $gnstr = $vals[9];
		my $gnend = $vals[10];
		my $orn = $vals[11];
		
		$data->{'GENES'}{$gnk}{$gnid}{$tlpk}{$tlpid}++;
		$data->{'GENES'}{$gnk}{$gnid}{$tlpgik}{$vals[6]}++;
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
			$data->{'RNAS'}{$rnak}{$rnaid}{$tlpk}{$tlpid}++;
			$data->{'RNAS'}{$rnak}{$rnaid}{$tlpgik}{$vals[6]}++;
			$data->{'PROTS'}{$tlpk}{$tlpid}{$rnak}{$rnaid}++;
			$data->{'PROTS'}{$tlpk}{$tlpid}{$rnagik}{$vals[4]}++;
		}
		
		if ( $gnmid ne '-' ) {
			$data->{'GENES'}{$gnk}{$gnid}{$gnmack}{$gnmid}++;
			$data->{'GENES'}{$gnk}{$gnid}{$gnmgik}{$vals[8]}++;
		}
		
		$data->{'TAXA'}{$txnk}{$txnid}{$tlpk}{$tlpid}++;
		$data->{'PROTS'}{$tlpk}{$tlpid}{$txnk}{$txnid}++;
		$data->{'PROTS'}{$tlpk}{$tlpid}{$gnk}{$gnid}++;
		$data->{'PROTS'}{$tlpk}{$tlpid}{$tlpgik}{$vals[6]}++;
		
		if ( $map ) {
# 		my $upac = $map->{$gnid};
			next unless $map->{$gnid};
			next unless my @upaccs = @{$map->{$gnid}};
			foreach my $upac ( @upaccs ) {
	# 		if ( $upac ) {
				$data->{'GENES'}{$gnk}{$gnid}{$upack}{$upac}++; # TODO fix this
				$data->{'RNAS'}{$rnak}{$rnaid}{$upack}{$upac}++ if $rnaid;
				$data->{'PROTS'}{$tlpk}{$tlpid}{$upack}{$upac}++;
				$data->{'UNIPROT'}{$upack}{$upac}{$gnk}{$gnid}++;
				$data->{'UNIPROT'}{$upack}{$upac}{$rnak}{$rnaid}++ if $rnaid;
				$data->{'UNIPROT'}{$upack}{$upac}{$tlpk}{$tlpid}++;
	# 		}
# 			else { $data->{'LOG'}{'noUpAc'}{$tlpid}++; }
			}
		}
	}
	return $data;
}

# fields of interest, origin at '0'
#~ my $engnk = 'ensemblGeneId'; # 2
#~ my $rnak = 'rnaAc'; # 3
#~ my $enrnak = 'ensemblRnaId'; # 4
#~ my $tlpk = 'proteinAc'; # 5
#~ my $entlpk = 'ensemblProtId'; # 6
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
		#~ my $tlpid = $vals[5];
		my $tlpid = substr $vals[5], 0, -2; # stripping the version
		my $entlpid = $vals[6];
		$data->{'GENES'}{$gnk}{$gnid}{$engnk}{$engnid}++;
		$data->{'GENES'}{$gnk}{$gnid}{$enrnak}{$enrnaid}++;
		$data->{'GENES'}{$gnk}{$gnid}{$entlpk}{$entlpid}++;
		$data->{'RNAS'}{$rnak}{$rnaid}{$engnk}{$engnid}++;
		$data->{'RNAS'}{$rnak}{$rnaid}{$enrnak}{$enrnaid}++;
		$data->{'RNAS'}{$rnak}{$rnaid}{$entlpk}{$entlpid}++;
		$data->{'PROTS'}{$tlpk}{$tlpid}{$engnk}{$engnid}++;
		$data->{'PROTS'}{$tlpk}{$tlpid}{$enrnak}{$enrnaid}++;
		$data->{'PROTS'}{$tlpk}{$tlpid}{$entlpk}{$entlpid}++;
	}
	return $data;
}

######################### entrez2ttl ##########################################

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
#		print $OUT $s."obo:$NS$fs$id obo:$TXNNS$fs$first" if $first;
		print $OUT $s."obo:$NS$fs$id ncbitaxon:$first" if $first;
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
