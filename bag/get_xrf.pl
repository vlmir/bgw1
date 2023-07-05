# $Id: get_xrf.pl 89 2006-01-18 10:52:47Z erant $
#
# Module  : get_xrf.pl
# Purpose : Extracts all xrf data from 'GO.xrf_abbs' file and updates the given
#			ontology file.
# See 'GO.xrf_abbs_spec' for the specification details.
# perl -w get_xrf.pl ../xrf/GO.xrf_abbs ../obo/pre_cco_$db.obo
#			$db in ("A_thaliana", "S_pombe", "S_cerevisiae", "H_sapiens")
# License : Copyright (c) 2006 Erick Antezana. All rights reserved.
#           This program is free software; you can redistribute it and/or
#           modify it under the same terms as Perl itself.
# Contact : Erick Antezana <erant@psb.ugent.be>
#
################################################################################
use Carp;
use strict;
use warnings;

use constant NL					=> "\n";
use constant TB					=> "\t";

BEGIN {
	unshift @INC, '../../onto-perl';
}
use OBO::CCO::CCO_ID_Term_Map;
use OBO::Parser::OBOParser;
use OBO::Core::Term;
use OBO::Core::Ontology;

################################################################################
#
# The allowed labels are:
#
################################################################################
use constant ABBREVIATION		=> 'abbreviation';
use constant SHORT_HAND_NAME	=> 'shorthand_name';
use constant DATABASE			=> 'database';
use constant OBJECT				=> 'object';
use constant SYNONYM			=> 'synonym';
use constant EXAMPLE_ID			=> 'example_id';
use constant GENERIC_URL		=> 'generic_url';
use constant URL_SYNTAX			=> 'url_syntax';
use constant URL_EXAMPLE		=> 'url_example';
################################################################################

# 1. Assume that the xrf files (GO.xrf_abbs, GO.curator_dbxrefs) were already gotten in the pipeline

# 2. load the xrf data into CCO:
my $go_xrf_abbs_path = shift @ARGV; # ../xrf/GO.xrf_abbs
my $my_parser = OBO::Parser::OBOParser->new();
my $obo_file = shift @ARGV;
my $onto = $my_parser->work($obo_file);
load_xrf_data_as_OBO();
exit;

################################################################################
#
# Load the data from the downloaded xrf's files.
# TODO: Consider ONLY the 'xrf' used in CCO?
#
################################################################################
sub load_xrf_data_as_OBO {
		
	open (GO_XRF_ABBS_FH, $go_xrf_abbs_path) || die "The $go_xrf_abbs_path file cannot be opened";
	my $go_xrf_abbs = do { local $/; <GO_XRF_ABBS_FH> }; # read the whole file
	close GO_XRF_ABBS_FH;
	
	# Clean the file:
	# The GO.xrf_abbs file has some blank lines with some spaces.
	# Besides, some lines are split into two lines.
	$go_xrf_abbs =~ s/!.*//g;		        # get rid of comments
	$go_xrf_abbs =~ s/\n\s*\n{1,}/<cS>/g;   # dirty 'RE' to slip the file
	my @go_xrf_abbs_chunks = split (/<cS>/, $go_xrf_abbs);
	my $cco_r_id_map = OBO::CCO::CCO_ID_Term_Map->new("../doc/CCO_r.ids"); # Set of IDs
	
	my $ref_term = OBO::Core::Term->new(); # REFERENCE_TERM
	$ref_term->id("CCO:R0000000");
	$ref_term->name("biological reference");
	$onto->add_term($ref_term);
	my $biological_continuant = $onto->get_term_by_id("CCO:U0000001");
	my $is_a = OBO::Core::Relationship->new();
	$is_a->id($ref_term->id()."_is_a_".$biological_continuant->id());
	$is_a->type("is_a");
	$is_a->link($ref_term, $biological_continuant);
	$onto->add_relationship($is_a);

	my $term;
	foreach my $chunk (@go_xrf_abbs_chunks){
		my $obo_ref_term = OBO::Core::Term->new();
		my $flag = 0;
		
		foreach my $line (split(/\n/, $chunk)){
			next if ($line =~ m/^!.*/); # bypass comments
			$line =~ s/\r//; # ^M artifacts from DOS
			
			if ($line =~ /abbreviation:\s*(.*)/) { # name
				$term = $1;
				$obo_ref_term->name($term);
				$flag = 1;
			}
			elsif ($line =~ /shorthand_name:\s*(.*)/) {}
			elsif ($line =~ /database:\s*(.*)/) { # definition
				#$obo_ref_term->def_as_string($1, "[http://www.geneontology.org/cgi-bin/xrefs.cgi]") if ($1);
				$obo_ref_term->def_as_string($1, "[]") if ($1);
				# fix: LIFEdb has a broken line!!!!
			}
			elsif ($line =~ /object:\s*(.*)/) {}
			elsif ($line =~ /synonym:\s*(.*)/) {}
			elsif ($line =~ /example_id:\s*(.*)/) {}
			elsif ($line =~ /generic_url:\s*(.*)/) { # comment
				$obo_ref_term->comment($1) if ($1);
			}
			elsif ($line =~ /url_syntax:\s*(.*)/) {}
			elsif ($line =~ /url_example:\s*(.*)/) {};
		}
		
		if ($flag) {
		#if (defined($obo_ref_term)) {
			my $xrf_id = $cco_r_id_map->get_cco_id_by_term ($term);
			if (!defined $xrf_id) { # Does this term have an associated ID?
				$xrf_id = $cco_r_id_map->get_new_cco_id("CCO", "R", $term);
			}
			$obo_ref_term->id($xrf_id);
			$onto->add_term($obo_ref_term);
			
			my $is_a_ref = OBO::Core::Relationship->new();
			$is_a_ref->id($obo_ref_term->id()."_is_a_".$ref_term->id());
			$is_a_ref->type("is_a");
			$is_a_ref->link($obo_ref_term, $ref_term);
			$onto->add_relationship($is_a_ref);
		}
	}
	#
	# For 'http' (special case due to name)
	#
	my $xrf_id = $cco_r_id_map->get_cco_id_by_term ("http");
	if (!defined $xrf_id) { # Does this term have an associated ID?
		$xrf_id = $cco_r_id_map->get_new_cco_id("CCO", "R", "http");
	}
	my $obo_http_ref_term = OBO::Core::Term->new();
	$obo_http_ref_term->id($xrf_id);
	$obo_http_ref_term->name("http");
	
	my $is_a_http_ref = OBO::Core::Relationship->new();
	$is_a_http_ref->id($obo_http_ref_term->id()."_is_a_".$ref_term->id());
	$is_a_http_ref->type("is_a");
	$is_a_http_ref->link($obo_http_ref_term, $ref_term);
	$onto->add_relationship($is_a_http_ref);
	
	$cco_r_id_map->write_map($cco_r_id_map); 
	
	open (FH, ">$obo_file") || die "The OBO export could not be done: ", $!;
	$onto->export(\*FH, 'obo');
	close FH;
}
################################################################################
#
# Load the data from the downloaded xrf's files.
# TODO: Consider ONLY the 'xrf' used in CCO?
#
################################################################################
sub load_xrf_data_as_OWL{
	open (GO_XRF_ABBS_FH, "../xrf/GO.xrf_abbs") || die "The GO.xrf_abbs file cannot be opened";
	my $go_xrf_abbs = do { local $/; <GO_XRF_ABBS_FH> }; # read the whole file
	close GO_XRF_ABBS_FH;
	
	$go_xrf_abbs =~ s/!.*//g;			# get rid of comments
	
	# The GO.xrf_abbs file has some blank lines with some spaces. 
	# Besides, some lines are split into two lines.
	$go_xrf_abbs =~ s/\n\s*\n{1,}/<cS>/g;	# dirty 'RE' to slip the file
	
	my @go_xrf_abbs_chunks = split (/<cS>/, $go_xrf_abbs);
	my $cco_r_id_map = OBO::CCO::CCO_ID_Term_Map -> new ("../doc/cco_r.ids"); # Set of IDs
	
	my $term;
	foreach my $chunk (@go_xrf_abbs_chunks){
		
		my @record = split(/\n/, $chunk);
		my $owl_record = "";
		foreach my $line (@record){
			next if ($line =~ s/^!.*//); # bypass comments
			if ($line =~ /abbreviation:\s*(.*)/) {
				$owl_record .= TB."<dc:contributor rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">".$1."</dc:contributor>".NL;
				$term = $1;
			}
			elsif ($line =~ /shorthand_name:\s*(.*)/) {}
			elsif ($line =~ /database:\s*(.*)/) {
				# fix: LIFEdb has a broken line!!!!
				$owl_record .= TB."<dc:publisher rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">".$1."</dc:publisher>".NL;
			}
			elsif ($line =~ /object:\s*(.*)/) {}
			elsif ($line =~ /synonym:\s*(.*)/) {}
			elsif ($line =~ /example_id:\s*(.*)/) {}
			elsif ($line =~ /generic_url:\s*(.*)/) {
				$owl_record .= TB."<dc:identifier rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">".$1."</dc:identifier>".NL;
			}
			elsif ($line =~ /url_syntax:\s*(.*)/) {}
			elsif ($line =~ /url_example:\s*(.*)/) {};
		}
		
		if ($owl_record) {
			my $xrf_id = $cco_r_id_map->get_cco_id_by_term ($term);
			if (!defined $xrf_id) { # Does this term have an associated ID?
				$xrf_id = $cco_r_id_map->get_new_cco_id("CCO", "R", $term);
			}
			print "<owl:Class rdf:ID=\"".obo_id2owl_id($xrf_id)."\">".NL.
					TB."<rdfs:subClassOf rdf:resource=\"#Reference\"/>".NL.
					$owl_record.
					"</owl:Class>".NL.NL;
		}
	}
	my $xrf_id = $cco_r_id_map->get_cco_id_by_term ("http");
	if (!defined $xrf_id) { # Does this term have an associated ID?
		$xrf_id = $cco_r_id_map->get_new_cco_id("CCO", "R", "http");
	}
	print "<owl:Class rdf:ID=\"".obo_id2owl_id($xrf_id)."\">".NL;
	print TB, "<rdfs:subClassOf rdf:resource=\"#Reference\"/>", NL;
	print TB, "<dc:contributor rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">http</dc:contributor>", NL;
	print "</owl:Class>", NL;
}
################################################################################
#
# Transform an OBO-type ID into an OWL-type one.
# e.g. CCO:I1234567 -> CCO_I1234567
#
################################################################################
sub obo_id2owl_id {
	$_[0] =~ s/:/_/;
	return $_[0];
}
################################################################################
