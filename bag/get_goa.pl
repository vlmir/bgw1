# $Id: get_goa.pl 1 2008-02-14 14:23:26Z erant $
#
# Script  : get_goa.pl
# Purpose : get GOA.
# Usage   : /usr/bin/perl -w get_goa.pl
# License : Copyright (c) 2008 Erick Antezana. All rights reserved.
#           This program is free software; you can redistribute it and/or
#           modify it under the same terms as Perl itself.
# Contact : Erick Antezana <erant@psb.ugent.be>

=head1 NAME

get_goa.pl - Get the GOA files.

=head1 DESCRIPTION

Get the GOA files.

=head1 AUTHOR

Erick Antezana, E<lt>erant@psb.ugent.beE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Erick Antezana

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut

use Carp;
use strict;
use warnings;

use DBI; # Database Interface
use DBD::ODBC;

BEGIN {
	push @INC, '/group/biocomp/cbd/users/erant/workspace/ONTO-PERL';
}
use OBO::CCO::GoaToRDF;


#
# constants
#
my $rdf_data_path = "/virtuoso/data/rdf/";
my $goa_data_path = "/virtuoso/data/goa/";

open (FH, "proteome2taxid") || die "Check the file 'proteome2taxid': ", $_;
my @entries = <FH>;
close FH;


#
# WGET from the EBI
#
#my $prefix = "ftp://ftp.ebi.ac.uk/pub/databases/GO/goa/proteomes/";
#foreach my $entry (@entries) {
#	$entry =~ /(.*)\s+(.*)\s+(.*.goa)/;
#	print "LINE: ", $1, " - ", $2, " - ", $3, "\n";
#	chdir("./goa") or warn "Cannot change directory: $!";
#	my $cmd = 'wget '.$prefix.$3;
#	my $output .= `$cmd 2>&1`;
#	print STDOUT $output;
#	chdir("..") or warn "Cannot change directory: $!";
#}

#
# concat the GOA files and get the 2.4GB file!
#
#system "cat /dev/null > ./goa/full-goa.goa";
#foreach my $entry (@entries) {
#	$entry =~ /(.*)\s+(.*)\s+(.*.goa)/;
#	chdir("./goa") or warn "Cannot change directory: $!";
#	my $cmd = 'cat '.$3.' >> full-goa.goa';
#	my $output .= `$cmd`;
#	#print STDERR $output;
#	chdir("..") or warn "Cannot change directory: $!";
#}
# optional?
#system "sort goa/full-goa.goa > goa/full-goa.goa.sort";
#system "mv goa/full-goa.goa.sort goa/full-goa.goa";

#
# get the individual RDFs
#
my $date;
chomp($date = `date`);
print "\nget the individual RDFs ($date):\n";

my $goa2rdf = OBO::CCO::GoaToRDF->new();
foreach my $entry (@entries) {
	$entry =~ /(.*)\s+(.*)\s+(.*.goa)/;
	my $goa_f_name = $3;
	(my $goa_in_rdf_f_name = $goa_f_name) =~ s/\.goa/\.rdf/;
	open (FH, ">".$rdf_data_path.$goa_in_rdf_f_name) || die $!;
	my $file_handle = \*FH;
	$file_handle = $goa2rdf->work($file_handle, $goa_data_path.$goa_f_name);
	close $file_handle;
}
chomp($date = `date`);
print "Finished RDF conversion ($date)\n";

#
# update the DB ($HOME/.odbc.ini)
#

chomp($date = `date`);
print "\nDB update with the GOA files ($date):\n";
my $dbh = DBI->connect('dbi:ODBC:Virtuoso530', 'dba', 'dbacco', { RaiseError => 1 });

my $file   = "/virtuoso/data/rdf/cco.rdf";
my $ns     = "http://www.semantic-systems-biology.org/ontology/rdf/GOA";
my $graph  = "http://www.semantic-systems-biology.org/ontology/rdf/GOA";
my $prefix = "http://www.semantic-systems-biology.org/ontology/rdf/";

foreach my $entry (@entries) {
	$entry =~ /(.*)\s+(.*)\s+(.*.goa)/;
	my $goa_f_name = $3;
	(my $goa_in_rdf_f_name = $goa_f_name) =~ s/\.goa/\.rdf/;
	$file  = $rdf_data_path.$goa_in_rdf_f_name;

	#
	# TMP: GOA namespace
	#
	$ns = $graph = $prefix."GOA";
	my $command = sprintf("DB.DBA.RDF_LOAD_RDFXML(file_to_string_output('%s'),'%s','%s')", $file, $ns, $graph);

	chomp($date = `date`);
	print "\tUploading: $goa_f_name ($date): ";
	my $sth = $dbh->prepare($command);
	$sth->execute();
	chomp($date = `date`);
	print "DONE ($date)\n";
}
$dbh->disconnect() if defined($dbh);

chomp($date = `date`);
print "Update finished ($date)\n";







