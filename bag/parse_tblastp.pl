#!/usr/local/bin/perl -w

=head2 parse_tblastp.pl

  Usage    - perl parse_tblastp.pl < tera-blastp_output_file > omcl_input_file.bpo
  Args     - 
  Function - parses tera-blastp output and format it for OrthoMCL
  
  
=cut

while (<>) {
	my (
	$query_id,
	$target_id,
	$percent_align,
	$query_start,
	$query_end,
	$target_start,
	$target_end,
	$significance,
	$query_length,
	$target_length
	) = split;
	print"$.;$query_id;$query_length;$target_id;$target_length;$significance;$percent_align;1:$query_start-$query_end:$target_start-$target_end\n";
}