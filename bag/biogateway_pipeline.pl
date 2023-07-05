# $Id: biogateway_pipeline.pl 1 2008-02-14 14:23:26Z erant $
#
# Script  : biogateway_pipeline.pl
# Purpose : Build up a RDF knowledgebase (ready for SPARQL queries) based on the OBO foundry ontologies.
# 		http://www.semantic-systems-biology.org/biogateway/querying
# Usage   : /usr/bin/perl -w biogateway_pipeline.pl
# License : Copyright (c) 2008 Erick Antezana. All rights reserved.
#           This program is free software; you can redistribute it and/or
#           modify it under the same terms as Perl itself.
# Contact : Erick Antezana <erick.antezana@gmail.com>

=head1 NAME

biogateway_pipeline.pl - Build up a RDF knowledgebase (ready for SPARQL queries) based on the OBO foundry ontologies and other resources (e.g. swissprot).

=head1 DESCRIPTION

Build up a RDF knowledgebase (ready for SPARQL queries) based on the OBO foundry ontologies and other resources (e.g. swissprot).

=head1 AUTHOR

Erick Antezana, E<lt>erick.antezana@gmail.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Erick Antezana

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut

use Carp;
use strict;
use warnings;

use DBI;    # Database Interface
use DBD::ODBC;
use Net::FTP;

BEGIN {
	unshift @INC, '/norstore/user/mironov/workspace/svn/onto-perl';
}

use OBO::CCO::GoaToRDF;
use OBO::CCO::NCBIToRDF;
use OBO::CCO::SwissProtToRDF;
use OBO::Parser::OBOParser;
use OBO::Util::Ontolome;

# NOTE: config, paths, etc according to norstore!

# my $scripts_path = "/norstore/user/mironov/workspace/svn/biogateway/pipeline/"; # not used currently
my $log_path     = "/norstore/user/mironov/workspace/bgw_release/log/";
my $data_path     = "/norstore/user/mironov/workspace/svn/data/"; # vlmir
my $rdf_data_path = $data_path."rdf/";
my $rdf_onto_data_path = $rdf_data_path."ontologies/";
my $rdf_onto_tc_data_path = $rdf_data_path."ontologies_tc/";
my $rdf_goa_data_path = $rdf_data_path."goa/";
my $rdf_ncbi_data_path = $rdf_data_path."ncbi/";
my $rdf_uniprot_data_path = $rdf_data_path."uniprot/";
my $obo_data_path = $data_path."obo/";
my $obo_tc_data_path =  $data_path."obo_tc/";
my $goa_data_path  = $data_path."goa/";
my $ncbi_data_path = $data_path."ncbi/";
my $uniprot_data_path =  $data_path."uniprot/";
my $onto_list_path = $data_path."ontologies.list";
my $biorel_path = $rdf_data_path . 'inhouse/biorel.rdf';
my  $tmp_obo_path = $data_path . 'tmp/';

my $prefix = "http://www.semantic-systems-biology.org/";
my $ns     = $prefix . 'SSB';
my $connect_string = 'dbi:ODBC:VirtuosoDEV';
my $db_user = 'test';
my $db_pswd = 'test_user';

my $download  = '1'; # set to '0' to skip download
my $transform = '0'; # set to '0' to skip file transformation 
my $upload    = '0'; # set to '0' to skip db upload
my $clear_graphs = '0'; # set to 1 to clear graphs before upload

my %OBO_foundry_files_location_by_name_non_cvs = ( # used only in %from_URL - vlmir
	'SBO_OBO.obo' => 'http://www.ebi.ac.uk/sbo/exports/Main/SBO_OBO.obo', 
	'fma_obo.obo' => 'http://obo.svn.sourceforge.net/viewvc/\*checkout\*/obo/fma-conversion/trunk/fma_obo.obo',
	'PSI-MOD.obo' => 'http://psidev.sourceforge.net/mod/data/PSI-MOD.obo',
);

 my %meta_ontologies = ( # used only in %from_URL - vlmir
#	'biometarel.obo' => 'http://www.psb.ugent.be/cbd/metarel/biometarel.obo', # UNCOMMENT for upload - vlmir
#	'metaonto.obo'   => 'http://www.psb.ugent.be/cbd/metarel/metaonto.obo' # UNCOMMENT for upload - vlmir
);

my %from_URL = 
  ( %OBO_foundry_files_location_by_name_non_cvs, %meta_ontologies ); # used by ToRDF(), db_update() (non tc graphs), get_ontology_via_wget()

################################################################################
#
#
# START!
#
#
################################################################################
chomp( my $date = `date` );
open( PIPELINE_LOG, ">>" . $log_path . "biogateway_pipeline.log" )
  || die "The biogateway_pipeline.log file couldn't be opened";
print PIPELINE_LOG
  "\n---------------------------------------------------------------\n\n";
print PIPELINE_LOG "\nThe biogateway pipeline began at: $date \n";

my $dbh =
  DBI->connect( $connect_string, $db_user, $db_pswd,
	{ RaiseError => 1 } ) if $upload;
	
chdir($data_path) or croak "Cannot change directory to $data_path: $!"; # default directory

if ($download) {
	get_obo_ontologies($tmp_obo_path); # vlmir - downloads into data/tmp dir
	foreach my $file_name (sort keys %from_URL) {
###		get_ontology_via_wget($file_name);
	}
#	system ("find obo -name *.obo > $onto_list_path") or croak "Can't create $onto_list_path: $!";

# copying obo files from data/tmp to data/obo
#  TODO - try next time one of these options:
system ("find $tmp_obo_path -name *.obo -exec cp {} $obo_data_path \;");
#my $cmd = "find tmp/ -name *.obo -exec cp {} obo/ \;";
#system $cmd;
}

# Generating the array of  paths for ontologies
#  my @ontologies = read_list_of_ontologies(); # with full paths
my @ontologies = get_list_of_ontologies (); # no full paths
  

# creating rdf files for ontologies
if ($transform) {
	chomp($date = `date`);
	print PIPELINE_LOG "Call to obo2rdf() ($date)\n";
	&obo2rdf(); # vlmir
	chomp($date = `date`);
	print PIPELINE_LOG "DONE ($date)\n";
}
# adding closures  to ontologies
if ($transform) {
	chomp($date = `date`);
	print PIPELINE_LOG "Call to make_tc() ($date)\n";
	&make_tc(); # vlmir
	chomp($date = `date`);
	print PIPELINE_LOG "DONE ($date)\n";
}

# DB update of ontologies
if ($upload) {
	chomp( $date = `date` );
	print PIPELINE_LOG "Call to db_update() ($date)\n";
	&db_update();
	chomp( $date = `date` );
	print PIPELINE_LOG "DONE ($date)\n";
}

# process NCBI taxonomy
chomp( $date = `date` );
print PIPELINE_LOG "Call to process_ncbi_taxonomy() ($date)\n";
#&process_ncbi_taxonomy();
chomp( $date = `date` );
print PIPELINE_LOG "DONE ($date)\n";

# process uniprot
chomp( $date = `date` );
print PIPELINE_LOG "Call to process_uniprot() ($date)\n";
#&process_uniprot();
chomp( $date = `date` );
print PIPELINE_LOG "DONE ($date)\n";

# process goa
chomp( $date = `date` );
print PIPELINE_LOG "Call to process_goa() ($date)\n";
#&process_goa();
chomp( $date = `date` );
print PIPELINE_LOG "DONE ($date)\n";

# $dbh->disconnect() if defined($dbh); # causes 'segmentation fault', does not affect upload

################################################################################
#
#
# 	END
#
#
################################################################################
print PIPELINE_LOG "The pipeline ended at: " . `date` . "\n";
close PIPELINE_LOG;
exit;


################################################################################
#
# Get UniProt
#
################################################################################
sub process_uniprot() {
	chomp( $date = `date` );
	print PIPELINE_LOG "Process UniProt ($date): \n";
	my @files = (
#	 'uniprot_trembl.dat.gz', # kills Virtuoso
	 'uniprot_sprot.dat.gz' );

# my $mappins_url = "ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/idmapping.dat.gz";	# vlmir
	my $up_url =
	"ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/";
	foreach my $gz_file (@files) {
		$gz_file =~ /(\S*).dat.gz/;
		my $g        = $1;
		my $dat_file = $g . '.dat';
		my $rdf_file = $g . '.rdf';
		
		#
		# Download UniProt files
		#
		if ($download) {
			my $rm_cmd = "rm $gz_file";
			my $output .= `$rm_cmd 2>&1`; # added rm - vlmir 
			print PIPELINE_LOG "Downloading: ", $gz_file, "\n";
			chdir($uniprot_data_path) or croak "Cannot change directory to $uniprot_data_path: $!";
			my $cmd = 'wget ' . $up_url . $gz_file;
			$output .= `$cmd 2>&1`;
			print PIPELINE_LOG "Unzipping $gz_file\n";	
			$cmd = "gunzip -c $gz_file >  $dat_file"; # added $dat_file - vlmir
			$output .= `$cmd 2>&1`;
			print PIPELINE_LOG $output;
			chdir($data_path) or croak "Cannot change directory to $data_path: $!";
		}
		

		#
		# UniProt To RDF
		#
		if ($transform) {
			print PIPELINE_LOG "Producing: ", $rdf_file, "\n";
			my $uniprot2rdf = OBO::CCO::SwissProtToRDF->new();
			open( FH, ">" . $rdf_uniprot_data_path . $rdf_file) || die $!;		
			my $file_handle = \*FH;
			$file_handle =
			  $uniprot2rdf->work(  $uniprot_data_path . $dat_file, $file_handle );
		}

		my $pre_f_name = $rdf_file;
		my $file       = $rdf_uniprot_data_path . $rdf_file;  
		
		#
		# DB update
		#
		if ($upload) {
			chomp( $date = `date` );
			print PIPELINE_LOG "\nDB update with the $g triples ($date):\n";
			clear_graphs ($g) if $clear_graphs;
			add_triples ($file, 'SSB', 'SSB_tc', $g);
			add_triples ($biorel_path, $g);		
		}
		chomp( $date = `date` );
		print PIPELINE_LOG "DONE ($date)\n";
	}
}

################################################################################
#
#
# DB update ($HOME/.odbc.ini)
#
#
################################################################################
sub db_update() {

	# http://svn.neurocommons.org/svn/trunk/product/load-rdf-directory.pl
	chomp( $date = `date` );
	print PIPELINE_LOG
	  "\nDB update of ontologies ($date): \n\n";
	  clear_graphs ('SSB', 'OBO', 'SSB_tc', 'OBO_tc') if $clear_graphs;

	foreach my $obo_file_name (@ontologies ) {	
#		$obo_file_path =~ /.*\/(\S+)\.obo/;
		if ($obo_file_name =~ /(\S+)\.obo$/) {
			my $graph_name = $1;
			my $rdf_file_name = $graph_name.'.rdf';		
			my $rdf_file_path = $rdf_onto_data_path.$rdf_file_name;		
			clear_graphs ($graph_name) if $clear_graphs;
			add_triples ( $rdf_file_path, 'SSB', 'OBO', $graph_name);
			add_triples ( $biorel_path, $graph_name);		
			my $graph_tc_name = $graph_name . '_tc';
			my $rdf_tc_file_path = $rdf_onto_tc_data_path.$rdf_file_name;
			clear_graphs ($graph_tc_name) if $clear_graphs;
			add_triples ($rdf_tc_file_path, 'SSB_tc', 'OBO_tc', $graph_tc_name);
			add_triples ($biorel_path, $graph_tc_name );			
		}
	}			
	add_triples ($biorel_path, 'SSB', 'OBO');
	add_triples ($biorel_path, 'SSB_tc', 'OBO_tc');
	
	chomp( $date = `date` );
	print PIPELINE_LOG "Update finished ($date)\n";
}

################################################################################
#
# Get the requested ontology via WGET
#
################################################################################
sub get_ontology_via_wget {

	my $obo_ontology_file_name = $_[0];

	print PIPELINE_LOG "Getting '", $obo_ontology_file_name, "':\n";
	chdir($obo_data_path) or croak "Cannot change directory to $obo_data_path: $!";
	my $rm_cmd = ' rm -rf ' . $obo_ontology_file_name;
	my $output = `$rm_cmd 2>&1`;
	my $cmd    = 'wget ' . $from_URL{$obo_ontology_file_name};
	$output .= `$cmd 2>&1`;
	print PIPELINE_LOG $output;
	my $cmd2 =
	  'dos2unix ' . $obo_ontology_file_name;   # for fma-obo.obo and PSI-MOD.obo
	$output .= `$cmd2 2>&1`;
	print PIPELINE_LOG $output;
	chdir($data_path) or croak "Cannot change directory to $data_path: $!";
	print PIPELINE_LOG "Checkout: OK\n";
}
################################################################################
#
# Process GOA
#
################################################################################
sub process_goa {
	
	my @entries;
	my $map_file = "proteome2taxid";
	my $goa_map_file_path = $data_path . $map_file;
	my $goa_url      = "ftp://ftp.ebi.ac.uk/pub/databases/GO/goa/proteomes/";
	
	#
	# DOWNLOAD: WGET from the EBI
	#
	if ($download) {
		print PIPELINE_LOG "Downloading: ", $map_file,  "\n";
		my $cmd          = 'wget ' . $goa_url . $map_file;
		my $output .= `$cmd 2>&1`;  
		print PIPELINE_LOG $output;  
	}	
	open( FH, $goa_map_file_path ) || die "Check the file 'proteome2taxid': ", $!;
	@entries = <FH>;
	close FH;
	
	if ($download) {
		system ("cd $goa_data_path");
		system ("rm *.goa") or warn "cannot delete files in $goa_data_path: $!\n";
		foreach my $entry (@entries) {
			$entry =~ /(.*)\s+(.*)\s+(.*.goa)/;
			print PIPELINE_LOG "LINE: ", $1, " - ", $2, " - ", $3, "\n";
			my $cmd = 'wget ' . $goa_url . $3;
			my $output .= `$cmd 2>&1`;
			print PIPELINE_LOG $output;
		}
		system ( "cd $data_path");
	}

	#
	# get the individual RDFs
	#
	if ($transform) {
		my $date;
		chomp( $date = `date` );
		print PIPELINE_LOG "\nGet the individual GOA RDFs ($date):\n";
		
		my $goa2rdf = OBO::CCO::GoaToRDF->new() or croak "Can't create a GoaToRDF object: $!\n";
		foreach my $entry (@entries) {
			$entry =~ /(.*)\s+(.*)\s+(.*.goa)/;
			my $goa_f_name = $3;
			( my $goa_in_rdf_f_name = $goa_f_name ) =~ s/\.goa/\.rdf/;
			open( FH, ">" . $rdf_goa_data_path . $goa_in_rdf_f_name ) || die $!;
			my $file_handle = \*FH;
			$file_handle =
			  $goa2rdf->work( $file_handle, $goa_data_path . $goa_f_name );
			close $file_handle;
		}
		chomp( $date = `date` );
		print PIPELINE_LOG "Finished GOA2RDF conversion ($date)\n";
	}

	#
	# update the DB (using $HOME/.odbc.ini)
	#
	if ($upload) {
		chomp( $date = `date` );
		print PIPELINE_LOG "\nDB update with the GOA files ($date):\n";
		clear_graphs ('GOA') if $clear_graphs;
	
		foreach my $entry (@entries) {
			$entry =~ /(.*)\s+(.*)\s+((.*).goa)/;
			my $pre_f_name = $4; # graph name
			my $goa_f_name = $3;
			next if ($4 eq '32579.B_aphidicola_5A'); # breaks the pipeline
			( my $goa_in_rdf_f_name = $goa_f_name ) =~ s/\.goa/\.rdf/;
			my $file = $rdf_goa_data_path . $goa_in_rdf_f_name;
			clear_graphs($prefix . $pre_f_name) if $clear_graphs;
			
			#
			# upload
			#			
			add_triples($file, 'SSB',  'GOA', 'SSB_tc', $pre_f_name);
			add_triples($biorel_path, $pre_f_name);
		}		
		add_triples($biorel_path, 'GOA');

		chomp( $date = `date` );
		print PIPELINE_LOG "Update finished ($date)\n";
	}
}
################################################################################
#
# Process NCBI
#
################################################################################
sub process_ncbi_taxonomy() {
	my $date;
	my $g          = "ncbi";
	my $pre_f_name = "ncbi.rdf";
	my $file       = $rdf_ncbi_data_path . $pre_f_name;

	if ($download) {
		chomp( $date = `date` );
		print PIPELINE_LOG "\nGet the NCBI taxonomy ($date):\n";
		get_ncbi_taxonomy_files_from_ftp();
		chomp( $date = `date` );
		print PIPELINE_LOG "DONE ($date)\n";
	
		#
		# unpack the ncbi files
		#
		chomp( $date = `date` );
		print PIPELINE_LOG "Unpack NCBI taxonomy files ($date)\n";
		chdir($ncbi_data_path) # necessary
		  or die "Cannot change directory to $ncbi_data_path: $!\n";
		my $ncbi_taxonomy_dump_filename = 'taxdump.tar.gz';
		my $cmd                         = "tar -xzf $ncbi_taxonomy_dump_filename";
		system ($cmd);
		chdir($data_path) or croak "cannot change directory to $data_path: $!\n";
		chomp( $date = `date` );
		print PIPELINE_LOG "DONE ($date)\n";
	}

	#
	# Get the RDF version:
	#
	if ($transform) {
		chomp( $date = `date` );
		print PIPELINE_LOG "Get the RDF version ($date)\n";
		my $ncbi2rdf = OBO::CCO::NCBIToRDF->new();
	
		open( FH, ">" . $file ) || die $!;
		my $file_handle = \*FH;
		$file_handle = $ncbi2rdf->work( $ncbi_data_path . "nodes.dmp",
			$ncbi_data_path . "names.dmp", $file_handle );
		close $file_handle;
		chomp( $date = `date` );
		print PIPELINE_LOG "DONE ($date)\n";
	}

	#
	# DB update
	#
	if ($upload) {
		chomp( $date = `date` );
		print PIPELINE_LOG "\nDB update with the NCBI taxonomy ($date):\n";
		clear_graphs ($g) if $clear_graphs;
		add_triples ($file, 'SSB', 'SSB_tc', $g);
		add_triples ($biorel_path, $g);
	}
	chomp( $date = `date` );
	print PIPELINE_LOG "DONE ($date)\n";
}

################################################################################
#
# Get the NCBI taxonomy files from NCBI via FTP
#
################################################################################
sub get_ncbi_taxonomy_files_from_ftp {
	print PIPELINE_LOG "Getting the taxonomy files: ";
	chdir($ncbi_data_path) or die "Cannot change directory to $ncbi_data_path: $!";
	my $ncbi_taxonomy_dump_filename = 'taxdump.tar.gz';
	my $rm_cmd                      = 'rm -f $ncbi_taxonomy_dump_filename';
	my $output                      = `$rm_cmd 2>&1`;

	# ftp://ftp.ncbi.nih.gov/pub/taxonomy/
	my $hostname = 'ftp.ncbi.nih.gov';
	my $username = 'anonymous';
	my $password = 'myname@mydomain.com';

	# Hardcode the directory and filename to get
	my $path_to_taxonomy = '/pub/taxonomy';

	# Open the connection to the host
	my $ftp = Net::FTP->new($hostname);
	$ftp->login( $username, $password );
	$ftp->cwd($path_to_taxonomy);

	# Now get the file and leave
	$ftp->binary;
	$ftp->get($ncbi_taxonomy_dump_filename);
	$ftp->quit;

	print PIPELINE_LOG $output;
	chdir($data_path) or croak "Cannot change directory to $data_path: $!";
	print PIPELINE_LOG "OK\n";
}

################################################################################
#
# Get the OBO ontologies via CVS
#
################################################################################

# puts the tree of obo ontologies into data/tmp
sub get_obo_ontologies {
	print PIPELINE_LOG "Getting '", 'OBO ontologies', "':\n";
	my $dir = shift; # full path to the download dir
	my $output = "";
#	my $rm_cmd = " rm $obo_data_path . *.obo";
#	my $output = `$rm_cmd 2>&1`;
	system ("rm -rf $dir");
	my $cmd1 =  'cvs -d :pserver:anonymous:@obo.cvs.sourceforge.net:/cvsroot/obo login';
	# in the line below obo is the target dir and obo/ontology/ is the source dir
#	my $cmd2 = 'cvs -d :pserver:anonymous:@obo.cvs.sourceforge.net:/cvsroot/obo co -d obo obo/ontology/'; 
	my $cmd2 = 'cvs -d :pserver:anonymous:@obo.cvs.sourceforge.net:/cvsroot/obo co -d $dir obo/ontology/'; 
	$output .= `$cmd1 2>&1` or warn " Cannot login to CVS\n";
	$output .= `$cmd2 2>&1`   or warn "Cannot downlod the directory obo/ontology\n";
	print PIPELINE_LOG $output;
#	system( "rm -r " . $obo_data_path . "CVS/>>" . $log_path . "biogateway_pipeline.log" ); # ???

	print PIPELINE_LOG "Checkout: OK\n";
}

################################################################################
#
#
# CONVERT TO RDF
#
#
################################################################################
sub obo2rdf() {
	chomp( $date = `date` );
	print PIPELINE_LOG "Converting to RDF ($date): \n\n";
#	chdir $data_path or croak "Can't change dir to $data_path".": $!\n"; # already there
	foreach my $obo_file_name (@ontologies ) {
		if ($obo_file_name =~ /(\S+)\.obo$/) {
	#		$obo_file_path =~ /(\S+)\.obo$/;
			my $obo_file_path = $obo_data_path . $obo_file_name;
			my $onto_name = $1;
			my $rdf_file_name = $onto_name.'.rdf';
			my $rdf_file_path = $rdf_onto_data_path.$rdf_file_name;
			chomp( $date = `date` );
			print PIPELINE_LOG "Converting $onto_name".".obo to RDF ($date): ";
			my $my_parser = OBO::Parser::OBOParser->new();
			my $ontology  = $my_parser->work($obo_file_path);
			open( FH, ">" . $rdf_file_path )
			  || die "Couldn't create $rdf_file_path: ", $!;
			$ontology->export( \*FH, 'rdf', 0, 1, 1 );  # non-reflex and SBB_URL
			close FH;
			chomp( $date = `date` );
			print PIPELINE_LOG "DONE ($date)\n";			
		}
	}
	chomp( $date = `date` );
	print PIPELINE_LOG "\nConversion the RDF finished ($date)\n";
}

################################################################################
#
#
# Getting the transitive closure ontologies in OBO and RDF
#
#
################################################################################
sub make_tc () {
	my $my_p = OBO::Parser::OBOParser->new();
	my $ome  = OBO::Util::Ontolome->new();
#	chdir $data_path or croak "Can't change dir to $data_path".": $!\n"; # already there
	chomp( $date = `date` );
	print PIPELINE_LOG "Making transitive closures ($date): \n\n";
	select( ( select(PIPELINE_LOG), $| = 1 )[0] );
	foreach my  $obo_file_name (@ontologies) {
		if ($obo_file_name =~ /(\S+)\.obo/) {
	#		$obo_file_path =~ /.*\/(\S+)\.obo/;
			my $obo_file_path = $obo_data_path . $obo_file_name;
			my $onto_name = $1;
			my $rdf_tc_file_name = $onto_name.'.rdf';
			my $rdf_tc_file_path = $rdf_onto_tc_data_path.$rdf_tc_file_name;
			my $obo_tc_file_name = $onto_name.'.obo';
			my $obo_tc_file_path = $obo_tc_data_path.$obo_tc_file_name;
			chomp( $date = `date` );
			print PIPELINE_LOG
			  "Making transitive closures for $onto_name ($date): ";
			my $onto = $my_p->work($obo_file_path);
			my $go_transitive_closure = $ome->transitive_closure($onto);
			open( FH1, ">" . $rdf_tc_file_path )
			  || die "Couldn't create $rdf_tc_file_path: ", $!;
			$go_transitive_closure->export( \*FH1, 'rdf', 1, 1, 1 ); # reflex and SBB_URL. 
			close FH1;
			select( ( select(FH1), $| = 1 )[0] );
			open( FH2, ">" . $obo_tc_file_path )
			  || die "Couldn't create $obo_tc_file_path: ", $!;
			$go_transitive_closure->export( \*FH2, "obo" );
			close FH2;
			select( ( select(FH2), $| = 1 )[0] );
			chomp( $date = `date` );
			print PIPELINE_LOG "DONE ($date)\n";
			select( ( select(PIPELINE_LOG), $| = 1 )[0] );			
		}
	}
	chomp( $date = `date` );
	print PIPELINE_LOG "\nConversion finished ($date)\n";
}

# adds triples from $rdf_file to the graphs @graphs
# args: rdf file name (fully qualified), list of graphs (without namespace)
# $dbh, $prefix and $ns must be defined outside
sub add_triples() {
	my ($rdf_file, @graphs) = @_;
	foreach my $graph_name (@graphs) {
		my $graph   = $prefix . $graph_name;		
		my $command = sprintf(
			"DB.DBA.RDF_LOAD_RDFXML_MT(file_to_string_output('%s'),'%s','%s')",
			$rdf_file, $ns, $graph );
		chomp( $date = `date` );
		print PIPELINE_LOG
		  "\n\tLoading to $graph_name: $rdf_file ($date): ";
		my $sth = $dbh->prepare($command);
		$sth->execute();
		chomp( $date = `date` );
		print PIPELINE_LOG "DONE ($date)\n";		
	}	
}

# clears graphs
# args: list of graphs (without namespace)
# $prefix and $dbh must be defined outside
sub clear_graphs {
	my @graphs = @_;
	foreach my $graph_name (@graphs) {
		my $graph   = $prefix . $graph_name;
		chomp( $date = `date` );
		print PIPELINE_LOG
		  "\n\tClearing: $graph_name ($date): ";
		my $command = sprintf("sparql clear graph '$graph'" );
		my $sth = $dbh->prepare($command);
		$sth->execute();		
		chomp( $date = `date` );
		print PIPELINE_LOG "DONE ($date)\n";
	}
}

# reads a file with ontology paths and returns @ontologies
# not used anymore
sub read_list_of_ontologies {	
	my @ontologies;
	open  FH,  '<', $onto_list_path or croak "Can't open '$onto_list_path': $!";
	while (my $line = <FH>) {
		next if ($line =~ /\A\#+/xms
			or $line =~ /_xp/xmsi
			or $line =~ /idspace/xms # do not break down
			or $line =~ /_bridge/xms
			or $line =~ /ro_edit/xms
			or $line =~ /ro_proposed/xms
			or $line =~ /BrendaTissue/xms
			or $line =~ /caro_to_bfo/xms
			or $line =~ /medaka_ontology/xms # kills Virtuoso, present twice in the list
			or $line =~ /EMAPA/xms
			or $line =~ /zea_mays_anatomy/xms # kills Virtuoso
			or $line =~ /gaz/xms
			or $line =~ /psi-ms/xms
			or $line =~ /mosquito_insecticide_resistance/xms
			or $line =~ /unit/xms
			or $line =~ /teleost_taxonomy/xms
		);
			push @ontologies, $line if ($line =~ /.*\/(\S+\.obo)\z/xms);
	}
	close FH;
	return @ontologies; 
}

sub get_list_of_ontologies {
	opendir( DIR, "$obo_data_path" ) || die("Cannot open the directory $obo_data_path!\n");
	my @dir = readdir(DIR);
	closedir(DIR);
	my @ontologies;
	foreach my $obo_file_name (@dir) {
		if ($obo_file_name =~ /^\S+\.obo$/xms) {
			next if ($obo_file_name =~ /\A\#+/xms
				or $obo_file_name =~ /_xp/xmsi
				or $obo_file_name =~ /idspace/xms # do not break down
				or $obo_file_name =~ /_bridge/xms
				or $obo_file_name =~ /ro_edit/xms
				or $obo_file_name =~ /ro_proposed/xms
				or $obo_file_name =~ /BrendaTissue/xms
				or $obo_file_name =~ /caro_to_bfo/xms
				or $obo_file_name =~ /medaka_ontology/xms # kills Virtuoso, present twice in the list
				or $obo_file_name =~ /EMAPA/xms
				or $obo_file_name =~ /zea_mays_anatomy/xms # kills Virtuoso
				or $obo_file_name =~ /gaz/xms
				or $obo_file_name =~ /psi-ms/xms
				or $obo_file_name =~ /mosquito_insecticide_resistance/xms
				or $obo_file_name =~ /unit/xms
				or $obo_file_name =~ /teleost_taxonomy/xms
				or $obo_file_name =~ /^pro\./xms # 30/03/10 break in obo to rdf conversion
				or $obo_file_name =~ /^\S+-to-\S+\./xms # 30/03/10 break in obo to rdf conversion
				or $obo_file_name =~ /^part_of\./xms # 30/03/10 break in obo to rdf conversion
				or $obo_file_name =~ /bridge/xms # 30/03/10 break in obo to rdf conversion
				or $obo_file_name =~ /uberon-/xms # 30/03/10 break in obo to rdf conversion
				or $obo_file_name =~ /uberon_/xms # 30/03/10 break in obo to rdf conversion
				or $obo_file_name =~ /_to_/xms # 30/03/10 break in obo to rdf conversion
				or $obo_file_name =~ /genes-/xms # 30/03/10 break in obo to rdf conversion
				or $obo_file_name =~ /fma-syn/xms # 30/03/10 break in obo to rdf conversion
				or $obo_file_name =~ /hpo-digits-xp/xms # 30/03/10 break in obo to rdf conversion
				or $obo_file_name =~ /prokph-/xms # 30/03/10 break in obo to rdf conversion
				or $obo_file_name =~ /ro_ucdhsc/xms # 31/03/10 break in adding closures
				);
			push @ontologies, $obo_file_name;		
		}
	}
	return @ontologies;	
}
