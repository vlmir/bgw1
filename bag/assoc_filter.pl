# $Id: assoc_filter.pl 120 2006-02-16 17:30:39Z erant $
#
# Module  : assoc_filter.pl
# Purpose : Filters out the lines having a GO/CCO ID and parses the GOAParser.
# Usage: perl -w assoc_filter.pl 4896 ../goa/25.H_sapiens.goa ../doc/go_cco.ids ../obo/pre_cco_core.obo ../obo/pre_cco_H_sapiens.obo
# License : Copyright (c) 2006 Erick Antezana. All rights reserved.
#           This program is free software; you can redistribute it and/or
#           modify it under the same terms as Perl itself.
# Contact : Erick Antezana <erant@psb.ugent.be>
#
################################################################################
use strict;
use warnings;
use Carp;

BEGIN {
	unshift @INC, '/group/biocomp/cbd/users/erant/workspace/ONTO-PERL';
}
use OBO::Parser::OBOParser;
use OBO::CCO::GoaParser;
use OBO::Core::Term;
use OBO::Core::Ontology;

use constant NL					=> "\n";
use constant TB					=> "\t";
################################################################################
my $taxon_id = shift @ARGV;
my $file_name = shift @ARGV;
my $go_cco_ids_table_path = shift @ARGV;
# open the go ids vs. cco ids table and put it into a map.
open (GO_CCO_IDS, "$go_cco_ids_table_path") || croak "The '$go_cco_ids_table_path' file couldn't be opened";
chomp(my @go_cco_ids = <GO_CCO_IDS>);
close GO_CCO_IDS;

my %go_cco_ids = ();
# key=go_id, value=cco_id	
foreach my $entry (@go_cco_ids) {
	$go_cco_ids{$1} = $2 if ($entry =~ /^(GO:.*)\s+(CCO:.*)/);
}
################################################################################
#
# Filters out the lines having a GO/CCO ID
#
################################################################################
my $assoc_filter_log = "../log/assoc_filter.log";
open (FILTER_LOG, ">>$assoc_filter_log") || croak "The $assoc_filter_log file couldn't be opened";
print FILTER_LOG "\n\nDate: ".`date`;
print FILTER_LOG "Filtering the gene association file (".$file_name."): ";

(my $file_name_cco_path = $file_name) =~ s/\.goa/\.cco/;
# initialize the generated assoc file
system "cat /dev/null > $file_name_cco_path";
my @go_ids = keys %go_cco_ids; # IDs from GO used in CCO

# fill the generated assoc file
foreach my $go_id (@go_ids) {
	# TODO improve this next line: the grep calls are inefficient
	my $cmd = "cat $file_name | grep [[:space:]]".$go_id."[[:space:]] | grep -v ".$go_id."[[:space:]][[:alpha:]][[:space:]]"." | sed 's/$go_id/$go_cco_ids{$go_id}/g'";
	system "$cmd >> $file_name_cco_path";
}

# sort the cco assoc file and clean the directory
my $tmp_file = $file_name_cco_path."tmp";
my $cmd = "sort $file_name_cco_path > $tmp_file";
system "$cmd; mv $tmp_file $file_name_cco_path";
	
print FILTER_LOG "OK";
close FILTER_LOG;
################################################################################
#
# GOA Parsing
#
################################################################################
my $organism;
if ($file_name =~ /.*\d{1,2}\.(.*)\.goa/) {
	$organism = $1;
} else {
	confess "The name of the organism is not defined";
}

my $old_file = shift @ARGV;
my $new_file = shift @ARGV;
my $map_file = "../doc/cco_b_".$organism.".ids";
my @files = ($old_file, $new_file, $file_name_cco_path, $map_file, "../doc/cco_b.ids");
my %taxa = (
	'4896' => 'Schizosaccharomyces pombe organism',
	'4932' => 'Saccharomyces cerevisiae organism', 
	'3702' => 'Arabidopsis thaliana organism',
	'9606' => 'Homo sapiens organism'
);

my $goa_parser = OBO::CCO::GoaParser->new();
my $new_ontology = $goa_parser->work(\@files, $taxa{$taxon_id});
################################################################################
