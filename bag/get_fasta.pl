#!/usr/local/bin/perl -w
=head2 get_fasta.pl

  Usage    - perl get_fasta.pl [id1 id2 ...] file1 [file2 ...] > output_fasta_file
  Args     - a list of NCBI taxon IDs (optional), a list of UniProt data files (*.dat)
  Function - extracts from Uniprot data files sequences in fasta format (one file per taxon)
  
=cut


use strict;
use warnings;
use Carp;
use SWISS::Entry;
$Carp::Verbose = 1;

# reading taxon IDs
my %taxa;
while ( @ARGV and ( $ARGV[0] !~ /\.dat$/xms ) ) {
	my $taxon = shift @ARGV;
	$taxa{ $taxon } = 1;
}
# extracting fasta
{
	local $/ = "\n//\n";
	while (<>) {
		my $entry = SWISS::Entry->fromText($_);	
		my $fasta = $entry->toFasta();
		my $oxs = $entry->OXs; # all NCBI ids
		my $taxon_id = $oxs->{'NCBI_TaxID'}{'list'}[0]{'text'}; # the primary ID
		next if ( %taxa and (! $taxa{ $taxon_id } ));
		my ($header_line, $seq) = $fasta =~ /\A(>.*?)$(.*)\z/xms; # \n is prepended to the sequence
		next if $header_line =~ /Fragment/; # skipping fragments, often very short
		my $protein_name = $entry->ID;
		my ( $accession ) = @{ $entry->ACs->{list} }; # primary accession
		my $out_file = "$taxon_id.fasta";
		open my $OUT, '>>',  $out_file || croak "The file '$out_file' couldn't be opened: $!";	
		print $OUT ">$taxon_id|$accession|$protein_name$seq";
		#~ print $OUT ">$taxon_id|$protein_name$seq";
		close $OUT;
	}
}

   
