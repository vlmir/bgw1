## filter out data  from sources for reference proteomes (individuually, only for taxa present in GPA/GPI files)
## Everything works but goa and intact take a lot of time

BEGIN {
	push @INC, '/datamap/home_mironov/git/scripts', '/norstore_osl/home/mironov/git/scripts';
}

use Carp;
use strict;
use warnings;

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};
use auxmod::SharedVars qw ( 
$download_dir
$projects_dir
$gpa_src_file
$gpi_txn_lst
$intact_src_file
$pazar_src_file
);
use auxmod::SharedSubs qw(
open_read
open_write
read_map 
print_counts 
benchmark
__date
extract_map
filter_tsv_by_map
);
my $dat_dir = "$projects_dir/data";
# my $dat_dir = $download_dir; # for testing
my $idm_dat_dir = "$dat_dir/idmapping"; # currently not used
my $up_dat_dir = "$dat_dir/uniprot";
my $goa_dat_dir = "$dat_dir/goa";
my $entrez_dat_dir = "$dat_dir/entrez";
my $intact_dat_dir = "$dat_dir/intact";
my $pazar_dat_dir = "$dat_dir/pazar";
# my $orthodb_dat_dir = "$dat_dir/orthodb"; # currently not used

############################### not used ###############################
#use threads;
#~ use threads::shared;
#~ $Config{useithreads} or croak ('Recompile Perl with threads to run this program.');
#~ use Exporter;
#~ use DownloadVars;
########################################################################
# TODO
# proper handling of archives ?

my ( $label, ) = @ARGV;
unless ( -e $dat_dir ) { mkdir $dat_dir or croak "failed to create dir '$dat_dir': $!"; }

my ( $start_time, $step_time, $cmd, $msg );
########################################################################
if ( $label eq 'uniprot' ) {
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
	my $label_dir = "$dat_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
	chdir "$label_dir"; system ( 'pwd' );
	my $map = extract_map ($gpi_txn_lst , 0 );
	## extracing accs from data files, ref proteomes only
	$step_time = time;
	foreach my $taxid ( keys %{$map} ) {
		my $cmd = "ln -s $download_dir/$label/$taxid.txt $taxid.txt";
		system $cmd;
		$cmd = "grep '^AC' $taxid.txt | cut -f 1 -d ';' | cut -d ' ' -f 4 | sort -u > $taxid.acc"; # TODO to be retested
		system $cmd;
	}
	$msg = "> Extracted UP ACs from *.txt files"; benchmark ( $step_time, $msg ); # no isoforms
	## extracing accs from fasta files, ref proteomes only; (including isoform ids)
	$step_time = time;
	foreach my $taxid ( keys %{$map} ) {
		my $cmd = "grep '^>' $download_dir/$label/$taxid.fasta | cut -f 2-3 -d '|' | sort -u > $taxid.fac"; # TODO test
		system $cmd;
	}
	$msg = "> Extracted UP ACs from *.fasta files"; benchmark ( $step_time, $msg ); # including isoforms
	## adding tax ids to fasta headers
	$step_time = time;
	foreach my $taxid ( keys %{$map} ) {
		my $in_file = "$download_dir/$label/$taxid.fasta";
		my $IN = open_read ( $in_file );
		my $out_file = "$taxid.fa";
		my $OUT = open_write( $out_file );
		while (<$IN>) {
			if ( substr ($_, 0, 1) eq '>' ) {
				substr ($_, 0, 1) = ">$taxid|";
	# 			substr ($_, 0, 1, ">$taxid|"); # the same as above
			}
			print $OUT $_;
		}
	}
	$msg = "> Added taxon IDs to the headers *.fasta => *.fa"; benchmark ( $step_time, $msg );
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );
}
########################################################################

# the uniprot chunk must be completed before launching the rest !!!

########################################################################
if ( $label eq 'goa' ) {
# TODO re-implement with a single pass through the file using map {UPAC => taxon_id} !!!
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
	my $label_dir = "$dat_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
# 	if (-e $label_dir) {$cmd = "rm -rf $label_dir";  print "\t>$cmd\n"; system $cmd;} 
# 	mkdir $label_dir or croak "failed to create dir: '$label_dir' $!";
	chdir "$label_dir"; system ( 'pwd' );
	my $map = extract_map ($gpi_txn_lst , 0 );
	foreach my $taxid ( keys %{$map} ) {
		my $gpa_path = "$taxid.gpa"; # for writing
		my $upac_path = "$up_dat_dir/$taxid.fac"; # TODO use $taxid.acc instead to avoid terms without definitions
		my $map = extract_map ( $upac_path, 0 );
		filter_tsv_by_map ( $gpa_src_file, $gpa_path, $map, 1 ); # TODO must be replaced !!!
	}
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}

########################################################################
# takes nearly 20h
# the filtering is by ref proteome taxa, not by UP ACs of ref proteomes
if ( $label eq 'idmapping' ) {
# 01# UniProtKB-AC
# 02# UniProtKB-ID
# 03# GeneID (EntrezGene)
# 04# RefSeq
# 05# GI
# 06# PDB
# 07# GO
# 08# UniRef100
# 09# UniRef90
# 10# UniRef50
# 11# UniParc
# 12# PIR
# 13# NCBI-taxon
# 14# MIM
# 15# UniGene
# 16# PubMed
# 17# EMBL
# 18# EMBL-CDS
# 19# Ensembl
# 20# Ensembl_TRS
# 21# Ensembl_PRO
# 22# Additional PubMed

	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
	my $label_dir = "$dat_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
# 	my $idm_src_file ="/norstore/user/mironov/git/scripts/parsers/t/data/idm.tsv"; # for testing
	my $idm_src_file ="$download_dir/$label/idmapping_selected.tab";
	chdir "$label_dir";  system ( 'pwd' );
	my $tax_map = extract_map ($gpi_txn_lst , 0 );
# 	foreach my $taxid ( keys %{$tax_map} ) {
# 		$step_time = time;
# 		my $upac_map = extract_map ( "$up_dat_dir/$taxid.acc", 0 );
# 		my $idm_path = "$idmapping_dir/$taxid.idm"; # for writing
# 		filter_tsv_by_map ( $idm_src_file, $idm_path, $upac_map, 0 ); # takes close to 5 days !!!
# 		$msg = "> Extracted refprot mappings from $idm_src_file for $taxid "; benchmark ( $step_time, $msg );
# 	}
	
	my $IN = open_read ( $idm_src_file );
	while ( <$IN> ) {
		my $line = $_;
		my @fields = split /\t/, $line;
		my $txn = $fields[12];
		if ( $tax_map->{$txn} ) {
			my $OUT = open_write ( "$txn.idm", '>>' );
			print $OUT $line;
			close $OUT;
		}
	}
	
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}
########################################################################
if ( $label eq 'entrez' ) {

	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
	my $label_dir = "$dat_dir/$label"; # $entrez_dat_dir
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
# 	if (-e $label_dir) {$cmd = "rm -rf $label_dir";  print "\t>$cmd\n"; system $cmd;} 
# 	mkdir $label_dir or croak "failed to create dir: '$label_dir' $!";
	chdir "$label_dir"; system ( 'pwd' );
	my @files = (
	'gene2accession', # must be the first one
	'gene_info',
	'gene2ensembl',
	); # in the order of processing time
	my $tax_map = extract_map ($gpi_txn_lst , 0 );
	foreach my $file ( @files ) {
		$step_time = time;
		my $file_dir = "$label_dir/$file"; # full path
# 		if (-e $file_dir) {$cmd = "rm -rf $file_dir";  print "\t>$cmd\n"; system $cmd;};
		mkdir $file_dir or croak "failed to create dir: '$file_dir' $!";
		my $src_path = "$download_dir/entrez/$file"; print "src: $src_path\n";
		
		foreach my $txnid ( keys %{$tax_map} ) {
			my $all_path = "$file_dir/$txnid.all"; # for writing
			my $refseq_path = "$file_dir/$txnid.ref"; # for writing
			my ($out, $keys);
			$cmd = "grep -P '^$txnid\t' $src_path > $all_path";
			system ( $cmd );
			if ( $file eq 'gene2accession' ) {
				my $refseq_acc_path = "$txnid.rac"; # Attn: moved all these into dir refseq_accs !!! TODO adjust !!
				$cmd = "cut -f 6 $all_path | grep _ | sort -u > $refseq_acc_path"; #only refseq accs have a '_'
				system $cmd;
				my $acc_map = extract_map ( $refseq_acc_path, 0 );
				$out = filter_tsv_by_map ($all_path, $refseq_path, $acc_map, 5);
# 				$keys = keys %{$out}; print "$txnid.refseq: $keys\n";
			}
			else {
				my $map_path = "$label_dir/gene2accession/$txnid.ref";
				my $map = extract_map ( $map_path, 1 );
				$out = filter_tsv_by_map ($all_path, $refseq_path, $map, 1);
# 				$keys = keys %{$out}; print "keys: $keys\n";
			}
		} # foreach my $txnid
		
		$msg = "> Extracted refprot data from $src_path"; benchmark ( $step_time, $msg );
	} # foreach my $file
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}

########################################################################
if ( $label eq 'intact' ) { #TODO to be double tested
## TODO re-implement with a single path through the file !!!
## TODO eliminate empty files !
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
	my $label_dir = "$dat_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
# 	if (-e $label_dir) {$cmd = "rm -rf $label_dir";  print "\t>$cmd\n"; system $cmd;} 
# 	mkdir $label_dir or croak "failed to create dir: '$label_dir' $!";
	chdir "$label_dir"; system ( 'pwd' );
	my $tax_map = extract_map ($gpi_txn_lst , 0 );
	foreach my $txnid ( keys %{$tax_map} ) {
		my $map = extract_map ( "$up_dat_dir/$txnid.acc", 0 ); 
		# all binary interaction where the interactor A comes from the given reference proteome (takes >~ 3h)
		my $IN = open_read ( $intact_src_file );
		my $first_int_refprot =  "$txnid.1rp";
		my $OUT = open_write ( $first_int_refprot); # this creates numerous empty files !
		while (<$IN>) {
			my @fields = split;
			my ($db, $acc) = split /:/, $fields[0];
			next unless $acc;
			print $OUT $_  if $map->{$acc};
		}
		close $IN;
		close $OUT;
		# both interactors from the given reference proteome (takes no time)
		my $both_int_refprot = "$txnid.2rp";
		$IN = open_read ( $first_int_refprot );
		$OUT = open_write ( $both_int_refprot ); # this creates numerous empty files ?
		while (<$IN>) {
			my @fields = split;
			my ($db, $acc) = split /:/, $fields[1];
			next unless $acc;
			print $OUT $_  if $map->{$acc};
		}
		close $IN;
		close $OUT;
	}
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}
########################################################################
if ( $label eq 'pazar' ) {
# TODO implement 
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
	my $label_dir = "$dat_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
# 	if (-e $label) {$cmd = "rm -rf $label_dir";  print "\t>$cmd\n"; system $cmd;} 
# 	mkdir $label or croak "failed to create dir: '$label_dir' $!";
	chdir "$label_dir"; system ( 'pwd' );
	print "> $cmd\n"; system $cmd;	
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}
########################################################################
# if ( $label eq 'orthodb' ) {
# 	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
# 	my $label_dir = "$dat_dir/$label";
# 		unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
# # 	if (-e $label) {$cmd = "rm -rf $label_dir";  print "\t>$cmd\n"; system $cmd;} 
# # 	mkdir $label or croak "failed to create dir: '$label_dir' $!";
# # 	chdir "$label_dir"; system ( 'pwd' );
# 	my @files = (
# 	'ODB8_EukOGs_genes_ALL_levels.txt',
# 	'ODB8_ProkOGs_genes_ALL_levels.txt'
# 	); 
# 	my $src_dir = "$download_dir/$label";
# 	my $txn_map = extract_map ( $refprot_taxa_map_path, 2 );
# 	foreach my $file ( @files ) {
# 		my $step_time = time;
# 		my $src_path = "$src_dir/$file"; print "src: $src_path\n";
# 		my $refprot_path = "$orthodb_dat_dir/refprot-$file"; print "outf: $refprot_path\n";
# 		my $out = filter_odb_by_tax ($src_path, $refprot_path, $txn_map, 3);
# 		my $keys = keys %{$out}; print "keys: $keys\n";
# 		$msg = "> Extracted refprot data from $src_path"; benchmark ( $step_time, $msg );
# 	}
# 	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
# }
################################################################################

## http://www.uniprot.org/uniprot/?query=keyword%3A%22Reference+proteome+[KW-1185]%22&sort=score # all ref proteomes
if ( $label eq 'test' ) {
	my $intact_src_file = '/norstore/project/ssb/workspace/data/test_download/intact/test.txt';
	`wc -l  /norstore/project/ssb/workspace/data/test_download/intact/test.txt`;

}
########################################################################
########################################################################

sub filter_odb_by_tax {
	# there 2 tax fields (0 and 3), format NCBI_TaxID:(taxon_name||odb_taxid)
	my ( 
	$in_file,
	$out_file, 
	$map, 
	$key_ind, # indexing starts with '0'; 
	) = @_;
	my %keys;
# 	open my $IN, '<', $in_file or croak "Cannot open file '$in_file': $!";
	my $IN = open_read ( $in_file );
# 	open my $OUT, '>', $out_file or croak "Cannot open file '$out_file': $!";
	my $OUT = open_write ( $out_file );
	while (<$IN>) {
		next if substr ( $_, 0, 1) eq "\n";
		next if substr ( $_, 0, 3) eq "odb";
		chomp;#print "ln: $_";
		my ( @fields ) = split /\t/;#rint "flds: @fields";
		next unless my $key = $fields[$key_ind];#print "key: $key";
		next unless my ( $tax_id, $second ) = split /\:/, $key;
		next unless $map->{$tax_id};
		$keys{$tax_id}++;
		print $OUT "$_\n";
	}
	close $IN;
	close $OUT;
	return \%keys; # should be this way, no conditionals
}

