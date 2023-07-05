#!/usr/local/bin/perl -w

=head2 parse_tblastp.pl

  Usage    - perl parse_tblastp.pl < tera-blastp_output_file > omcl_input_file.bpo
  Args     - 
  Function - parses m8 blastp output and formats it for OrthoMCL (bpo format). Protein IDs must be in the form 'prot_ID|prot_length'
  
  
=cut
my $time_stamp = `date`;
print "started $time_stamp\n";
use Data::Dumper;
my @bpo;# holds all the data for the bpo file 
my $current_query_id = "";
my $current_target_id = "";
while (<>) {

	my (
	$query_head, # the header in the fasta file
	$target_head, # the header in the fasta file
	$percent_align, # perscent of identity in the alignement
	$align_leng, # alignement length
	$mismatches, 
	$gaps, 
	$query_start, 
	$query_end, 
	$target_start, 
	$target_end, 
	$significance,
	$bit_score, 
	) = split;
	my ($query_id, $query_length) =  split (/\|/, $query_head);
	my ($target_id, $target_length) =  split (/\|/, $target_head);
	my @hsp = ($query_start,$query_end,$target_start,$target_end);
	my @hsps;

	if ($query_id ne $current_query_id){ # new query, adding a new entry
#		print "new query $query_id\n";	
		$current_query_id = $query_id;
		$current_target_id = $target_id;
		push @hsps, \@hsp;
		my @entry = ($query_id,
					$query_length,
					$target_id,
					$target_length,
					$significance,
					$percent_align,
					\@hsps);
		push @bpo, \@entry; 
	}
	elsif ($target_id ne $current_target_id) { # new target, adding a new entry
#		print "new target $target_id\n";
		$current_target_id = $target_id;
		push @hsps, \@hsp;
		my @entry = ($query_id,
					$query_length,
					$target_id,
					$target_length,
					$significance,
					$percent_align,
					\@hsps);
		push @bpo, \@entry; 
		
	}
	else { # another HSP for an existing entry
		push @{$bpo[-1][6]}, \@hsp;
	}
}
my $count = 0;
foreach (@bpo) {
	my @entry = @$_; 
	my $line = "";
	for (my $i = 0; $i < 6; $i++) {		
		$line .= $entry[$i].';';
	}
	my $hsps = "";
	my $hsp_count = 0;
	foreach (@{$entry[6]}) {  
#		my @hsp = @$_; 		
		$hsp_count++;
		my ($query_start, $query_end, $target_start, $target_end) = @$_; 
		$hsps .= "$hsp_count:$query_start-$query_end:$target_start-$target_end."; 

		
	}
	$line .= $hsps;
	$count++;
	$line = "$count;$line";

	print "$line\n";
	
}
$time_stamp = `date`;
print "ended $time_stamp\n";
#print Dumper(@bpo);