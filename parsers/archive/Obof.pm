package parsers::Obof;

use strict;
use warnings;
use Carp;

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};

use auxmod::SharedSubs qw( 
char_http __date 
print_counts 
open_read
open_write
write_ttl_preambule
);
use auxmod::SharedVars qw(
%uris
$rex_dblq
);
my @rlskeys = qw ( ptn2bp ptn2mf ptn2cc );
# my @rel_name_spaces = ( 'BFO', 'RO', 'SIO' ); # not used anymore

sub obo2ttl {
	# Note: namespaces absent in %uris converted to 'obo'
	my ( 
	$self,
	$onto, 
	$out_path, # file path for writing 
	$mode # 'rdfs' | 'owl'
	) = @_;
	my $class_tag = "$mode:Class";
	my $fs = '_'; # for id conversion from OBO to URI
	my %buffers; # rdf_id => buffer
	my $buffer = '';
	my $uris = \%uris;
	my $OUT = open_write ( $out_path );
	
	# ------------- Preamble: namespaces -------------------------------
	### Preambule of RDF file
	$buffer = write_ttl_preambule ( $uris,  );

	my $s = " ;\n\t"; # a substitute for subject
	my $sp = " ,\n\t\t"; # a substitute for subject and predicate

	

	### Properties
	$buffer .= <<BFR;
	
#	///////////////////////////////////////////////////////////////////////////////////////
#	//
#	// Properties
#	//
#	///////////////////////////////////////////////////////////////////////////////////////
BFR
	
	print $OUT $buffer; $buffer = "";
	
	# ----------------------- ID mapping -------------------------------		
	my $id_map = map_rel_ids ( $onto  ); # print  Dumper($id_map);
	my @all_relationship_types = values(%{$onto->{RELATIONSHIP_TYPES}}); # objects 'OBO::Core::RelationshipType'
	
	# ------------------------------------------------------------------
	foreach my $relationship_type (@all_relationship_types) {
		my $obo_id = $relationship_type->id();
		next if $obo_id eq 'is_a';
		my $rdf_id = $id_map->{$obo_id};
		croak "Bad RDF id: $rdf_id" unless $rdf_id =~ /^(\w+?)_(\S+)$/xms ; # TODO move out of the loop
		my $NS = $1;
		my $subid = $2;
		my $ns = set_ns ( lc $NS, \%uris );
		
		my $uri = $uris->{$ns}; # with a trailing '/' or '#'
		my $buffer;			
		$buffer .= "\n### $uri$rdf_id ###\n";
		$buffer .= "\n$ns:$rdf_id a owl:ObjectProperty";
		$buffer .= $s."rdfs:subPropertyOf owl:SymmetricProperty" if ($relationship_type->is_symmetric() == 1);
		$buffer .= $s."rdfs:subPropertyOf owl:TransitiveProperty" if ($relationship_type->is_transitive() == 1);
		# not in biorel:
		# $buffer .= $s."rdfs:subPropertyOf owl:CyclicProperty" if ($relationship_type->is_cyclic() == 1);
		# not supported by owl 1:
		# $buffer .= $s."rdfs:subPropertyOf owl:AntiSymmetricProperty" if ($relationship_type->is_anti_symmetric() == 1);
		# $buffer .= $s."rdfs:subPropertyOf owl:ReflexiveProperty" if ($relationship_type->is_reflexive() == 1);
		# ------------------------ name ----------------------------
		if (defined $relationship_type->name()) {
			$buffer .= $s.'skos:prefLabel "'.&char_http($relationship_type->name()).'"';
		} else {
			# skipping the rest of the data, contact those guys
			carp "Relationship type '$obo_id' has no name, skipping the rest";
			next;
		}
		# ------------------------- is_a ---------------------------
		my $rt = $onto->get_relationship_type_by_id('is_a');
		if (defined $rt)  {
			my @heads = @{$onto->get_head_by_relationship_type($relationship_type, $rt)};
			if ( @heads ) {
				my $head = shift @heads;
				my $head_id = $head->id();
				my $rdf_id = $id_map->{$head_id};
				$buffer .= $s."rdfs:subPropertyOf $ns:$rdf_id";
				foreach my $head (@heads) {
					my $head_id = $head->id();
					my $rdf_id = $id_map->{$head_id};
					$buffer .= $sp."$ns:$rdf_id";
				}
			}
		}
		# -------------------------- def -------------------------------
		if (defined $relationship_type->def()->text()) {
			$buffer .= $s.'skos:definition "'.&char_http($relationship_type->def()->text()).'"';
		}
		# ----------------------- xref -----------------------------
		my @sorted_xrefs = __sort_by(sub {lc(shift)}, sub { OBO::Core::Dbxref::as_string(shift) }, $relationship_type->xref_set_as_string());
		if (@sorted_xrefs ) { 
			my $xref = shift @sorted_xrefs;
			$buffer .= $s.'skos:relatedMatch "'.$xref->db().':'.$xref->acc().'"';
			foreach my $xref (@sorted_xrefs) {
				$buffer .= $sp.'"'.$xref->db().':'.$xref->acc().'"';
			}
		}
		# ------------------------- namespace ----------------------
# 		foreach my $nspace ($relationship_type->namespace()) {
# 			# seems empty
# 			$buffer .= $s.'oboInOwl:hasOBONamespace "'.$nspace.'"';
# 		}
		# ---------------------- id --------------------------------
		$buffer .= $s.'oboInOwl:id "'.$obo_id.'"';
		# ----------------------- synonym ------------------------------
		# TODO other types of synonyms
		my @syns = $relationship_type->synonym_set();
		if ( @syns ) {
			my $synonym = shift @syns;
			my $scope = $synonym->scope();
			my $text = &char_http($synonym->def()->text());			
			$buffer .= $s.'skos:altLabel "'.$text.'"' if $scope eq 'EXACT';
			foreach my $synonym ( @syns ) {
				my $scope = $synonym->scope();
				my $text = &char_http($synonym->def()->text());			
				$buffer .= $sp.$text.'"' if $scope eq 'EXACT';
			}
		}
		# ----------------------- comment ------------------------------
		if(defined $relationship_type->comment()){
			$buffer .= $s.'rdfs:comment "'.&char_http($relationship_type->comment()).'"'; # sic !
		}
		# ----------------------- inverse_of ---------------------------
		my $ir = $relationship_type->inverse_of();
		$buffer .= $s."owl:inverseOf $ns:$id_map->{$ir->id()}" if defined $ir;
		# ---------------------- propertyChains -------------------------
		my @chains; # both for transitive_over and holds_over_chain
		# transitive_over 
		foreach my $transitive_over ($relationship_type->transitive_over()->get_set()) {
			my ( $obo_id2, $rel_name2 ) = split / ! /, $transitive_over;
			my $rdf_id2 = $id_map->{$obo_id2};
			my ( $ns2, $subid2 ) = split_id ( $rdf_id2, '_' );
			push @chains, "($ns:$rdf_id $ns2:$rdf_id2)";
		}
		# holds_over_chain 
		foreach my $holds_over_chain ($relationship_type->holds_over_chain()) {
			my ( $rdf_id1, $rdf_id2 ) = ( $id_map->{@{$holds_over_chain}[0]}, $id_map->{@{$holds_over_chain}[1]} );
			my ( $ns1, $subid1 ) = split_id ( $rdf_id1, '_' );
			my ( $ns2, $subid2 ) = split_id ( $rdf_id2, '_' );
			push @chains, "($ns1:$rdf_id1 $ns2:$rdf_id2)";
		}
		$buffer .= $s.'owl:propertyChainAxiom '.join (', ', @chains) if @chains; # sic!
		# -------------------- domain -----------------------------------
		my @domains = $relationship_type->domain()->get_set();
		if ( @domains ) {
			my $domain = shift @domains;
			$domain =~ /\A(\w+):(\S+)/xms; # sic!
			my ( $NS, $subid ) = ( $1, $2 );
			my $ns = lc $NS;
			$ns = $uris{ns} ? $ns : 'obo';
			$ns = $id_map->{$ns} if $id_map->{$ns};
			$buffer .= $s."rdfs:domain $ns:$NS$fs$subid";
			foreach my $domain ( @domains ) {
				$domain =~ /\A(\w+):(\S+)/xms; # sic!
				my ( $NS, $subid ) = ( $1, $2 );
				my $ns = lc $NS;
				$ns = $uris{ns} ? $ns : 'obo';
				$ns = $id_map->{$ns} if $id_map->{$ns};
				$buffer .= $sp."$ns:$NS$fs$subid";
			}
		}
		# ----------------------- range ---------------------------------
		my @ranges = $relationship_type->range()->get_set();
		if ( @ranges ) {
			my $range = shift @ranges;
			$range =~ /\A(\w+):(\S+)/xms;
			my ( $NS, $subid ) = ( $1, $2 );
			my $ns = lc $NS;
			$ns = $uris{ns} ? $ns : 'obo';
			$buffer .= $s."rdfs:range $ns:$NS$fs$subid";
			foreach my $range ( @ranges ) {
				$range =~ /\A(\w+):(\S+)/xms;
				my ( $NS, $subid ) = ( $1, $2 );
				my $ns = lc $NS;
				$ns = $uris{ns} ? $ns : 'obo';
				$buffer .= $sp."$ns:$NS$fs$subid";
			}
		}
		$buffer .= " .\n"; # end of ObjectProperty

		# -------------------------- Axiom -----------------------------
		if (defined $relationship_type->def()->text()) {
			$buffer .= "[";
			$buffer .= "rdf:type owl:Axiom";
			for my $ref ($relationship_type->def()->dbxref_set()->get_set()) {
				$buffer .= $s.'skos:relatedMatch "'.$ref->db().':'.$ref->acc().'"';
			}
			$buffer .= $s.'owl:annotatedTarget "'.&char_http($relationship_type->def()->text()).'"';
			$buffer .= $s."owl:annotatedSource $ns:$rdf_id";
# 			$buffer .= $s."owl:annotatedProperty obo:IAO_0000115";
			$buffer .= $s."owl:annotatedProperty skos:definition";
			$buffer .= "\n]\n";
		}
		
		# 
		# end of relationship type
		#
		$buffers{$rdf_id} = $buffer;
	}
	map { print $OUT $buffers{$_} } sort keys %buffers; %buffers = ();	
	
######################### Not used #####################################
		#~ my $buffer;
		#~ # functional
		#~ $buffer .= $s."",$ns,':functional>true</',$ns,":functional>\n" if ($relationship_type->functional() == 1);
		#~ # inverse_functional
		#~ $buffer .= $s."",$ns,':inverse_functional>true</',$ns,":inverse_functional>\n" if ($relationship_type->inverse_functional() == 1);
		#~ # alt_id
		#~ foreach my $alt_id ($relationship_type->alt_id()->get_set()) {
			#~ $buffer .= $s."",$ns,':alt_id>', $alt_id, '</',$ns,":alt_id>\n";
		#~ }
		#~ # subset
		#~ foreach my $sset_name ($relationship_type->subset()) {
			#~ if ($onto->subset_def_map()->contains_key($sset_name)) {
				#~ $buffer .= $s."$ns:subset>",$sset_name,"</$ns:subset>\n";
			#~ } else {
				#~ carp "\nThe relationship type ", $relationship_type->id(), " belongs to a non-defined subset ($sset_name).\nYou should add the missing subset definition.\n";
			#~ }
		#~ }
		#~ # is_class_level
		#~ $buffer .= $s."",$ns,':is_class_level>true</',$ns,":is_class_level>\n" if ($relationship_type->is_class_level() == 1);
		#~ $buffer = "";

########################################################################		
	$buffer .= <<BFR;
#	///////////////////////////////////////////////////////////////////////////////////////
#	//
#	// Classes
#	//
#	///////////////////////////////////////////////////////////////////////////////////////
BFR
	print $OUT "\n$buffer"; $buffer = "";
	
	my $special_cases = {'sio' => 1};
	my @all_terms = @{$onto->get_terms_sorted_by_id()};
	foreach my $term (@all_terms) {
		my $term_id = $term-> id();
		my ($rdf_id, $ns) = set_rdf_class_id ( $term_id, $special_cases );
		my $buffer;
		my $uri = $uris->{$ns};
		$buffer .= "\n### $uri$rdf_id ###\n";
# 		$buffer .= "\n$ns:$rdf_id rdfs:subClassOf $class_tag";
		$buffer .= "\n$ns:$rdf_id a $class_tag";
		# ------------------- name -------------------------------------
		my $term_name = $term->name();
		my $term_name_to_print = (defined $term_name) ? $term_name :'NA';
		
		$buffer .= $s.'skos:prefLabel "'.&char_http($term_name_to_print).'"';
		
		# -------------------- is_a ------------------------------------
		my $rt = $onto->get_relationship_type_by_id('is_a');
		if (defined $rt)  {
			my @heads = @{$onto->get_head_by_relationship_type($term, $rt)};
			if ( @heads ) {
				my $head = shift @heads;
				my $head_id = $head->id();
				my ($rdf_id, $ns) = set_rdf_class_id ( $head_id, $special_cases );
				$buffer .= $s."rdfs:subClassOf $ns:$rdf_id";
				foreach my $head ( @heads ) { # if any, no need to test
					my $head_id = $head->id();
					my ($rdf_id, $ns) = set_rdf_class_id ( $head_id, $special_cases );
					$buffer .= $sp."$ns:$rdf_id";
				}
			}
		}
		# ------------------ relationship ------------------------------
		foreach my $rt ( @{$onto->get_relationship_types()} ) {
			my $obo_rid = $rt->id();
			if ($obo_rid && $obo_rid ne 'is_a') { # is_a is printed above
				my $rdf_rid = $id_map->{$obo_rid};
				$rdf_rid =~ /\A(\w+)_(\S+)/xms;
				my ( $RNS, $subid ) = ( $1, $2 );
				my $rns = set_ns (lc $RNS, \%uris);
				my @heads = @{$onto->get_head_by_relationship_type($term, $rt)};
				foreach my $head ( @heads ) {	
					my $head_id = $head->id();
					my ($rdf_id, $ns) = set_rdf_class_id ( $head_id, $special_cases );
					if ( $mode eq 'rdfs' ) {
						$buffer .= $s."$rns:$rdf_rid $ns:$rdf_id";
					} elsif ( $mode eq 'owl' ) {
						$buffer = write_prop ( $buffer, $rns, $rdf_rid, $ns, $rdf_id );
					}
				}
			}
		} # end of foreach $rt
		
		# ------------------------- id ---------------------------------
		$buffer .= $s.'oboInOwl:id "'.$term_id.'"';
		# -------------------------- def -------------------------------
		if (defined $term->def()->text()) {
			$buffer .= $s.'skos:definition "'.&char_http($term->def()->text()).'"';
		}
		# ---------------------- xref ----------------------------------
		my @sorted_xrefs = __sort_by(sub {lc(shift)}, sub { OBO::Core::Dbxref::as_string(shift) }, $term->xref_set_as_string());
		if ( @sorted_xrefs ) {
			my $xref =  shift @sorted_xrefs;
			$buffer .= $s.'skos:relatedMatch "'.$xref->db().':'.$xref->acc().'"';
			foreach my $xref (@sorted_xrefs) {
				$buffer .= $sp.'"'.$xref->db().':'.$xref->acc().'"';
			}
		}
		# ----------------------- synonym ------------------------------
		my @syns = $term->synonym_set();
		if ( @syns ) {
			my $synonym = shift @syns;
			my $scope = $synonym->scope();
			my $text = &char_http($synonym->def()->text());			
			if ( $scope eq 'EXACT' ) {
				$buffer .= $s.'skos:altLabel "'.$text.'"';
			}
			foreach my $synonym (@syns) { # if any, no need to check
				my $scope = $synonym->scope();
				my $text = &char_http($synonym->def()->text());			
				if ( $scope eq 'EXACT' ) {
					$buffer .= $s.'skos:altLabel "'.$text.'"';
				}
			}
		}
		# ---------------------------- subset --------------------------
		## commented because something is wrong with $ns
		## should be go#subset_name instead of obo#subset_name
# 		foreach my $sset_name ($term->subset()) {
# 			if ($onto->subset_def_map()->contains_key($sset_name)) {
# 				$buffer .= $s."oboInOwl:inSubset $ns:$ns#$sset_name";
# 			} else {
# 				carp "\nThe term ", $term->id(), " belongs to a non-defined subset ($sset_name).\nYou should add the missing subset definition.\n";
# 			}
# 		}
		# ---------------------------- namespace --------------------------
		foreach my $ns ($term->namespace()) {
			$buffer .= $s.'oboInOwl:hasOBONamespace "'.$ns.'"';
		}
		
		# -------------------------- Axiom -----------------------------
		## commented because some xrefs to defs in GO contain uris; the culprit is most like the '&' char
# 		if (defined $term->def()->text()) {
# 			$buffer .= "\t<owl:Axiom";
# 			for my $ref ($term->def()->dbxref_set()->get_set()) {
# 				$buffer .= $s."skos:relatedMatch ".$ref->db().':'.$ref->acc()."</skos:relatedMatch";
# 			}
# 			$buffer .= $s."owl:annotatedTarget ".&char_http($term->def()->text())."</owl:annotatedTarget";
# 			$buffer .= $s."owl:annotatedSource $ns:$rdf_id";
# 			$buffer .= $s."owl:annotatedProperty skos;definition";
# 			$buffer .= "\t</owl:Axiom";
# 		}
	$buffer .= " .\n"; # end of 
		$buffers{$rdf_id} = $buffer;
	}
	map { print $OUT $buffers{$_} } sort keys %buffers;	%buffers = ();

		
# ----------------------------------------------------------------------
# copy from rel types:
		#~ $buffers{$rdf_id} = $buffer;
			#~ $buffer .= "\t<owl:Axiom";
			#~ for my $ref ($relationship_type->def()->dbxref_set()->get_set()) {
				#~ $buffer .= $s."skos:relatedMatch ".$ref->db().':'.$ref->acc()."</skos:relatedMatch";
			#~ }
			#~ $buffer .= $s."owl:annotatedTarget ".&char_http($relationship_type->def()->text())."</owl:annotatedTarget";
			#~ $buffer .= $s."owl:annotatedSource rdf:about=\"&$ns:$rdf_id\"";
			#~ $buffer .= $s."owl:annotatedProperty obo;IAO_0000115";
			#~ $buffer .= "\t</owl:Axiom";

############################## Not used ################################
		#~ # ------------------------ alt_id ------------------------------
		#map	{$buffer .= $s."$ns:hasAlternativeId '$_</$ns:hasAlternativeId"} ($term->alt_id()->get_set());
		#~ # ---------------------- property_value ------------------------
		#~ my @property_values = sort {$a->id() cmp $b->id()} $term->property_value()->get_set();
		#~ foreach my $value (@property_values) {
			#~ if (defined $value->head()->instance_of()) {
				#~ $buffer .= $s."$ns:property_value";
				#~ $buffer .= "\t\t\t<rdf:Description";
					#~ $buffer .= "\t\t\t\t<$ns:property ", $value->type(),'</',$ns,":property";
					#~ $buffer .= "\t\t\t\t<$ns:value rdf:type=\"",$value->head()->instance_of()->id(),"\" ", $value->head()->id(),'</',$ns,":value";
				#~ $buffer .= "\t\t\t</rdf:Description";
				#~ $buffer .= $s."/$ns:property_value ";
			#~ } else {
				#~ $buffer .= $s."$ns:property_value";
				#~ $buffer .= "\t\t\t<rdf:Description";
					#~ $buffer .= "\t\t\t\t<$ns:property ", $value->type(),'</',$ns,":property";
					#~ $buffer .= "\t\t\t\t<$ns:value ", $value->head()->id(),'</',$ns,":value";
				#~ $buffer .= "\t\t\t</rdf:Description";
				#~ $buffer .= $s."/$ns:property_value ";
			#~ }
		#~ }
		
	return $id_map;	
}


sub obo2xml {
	# Note: namespaces absent in %uris converted to 'obo'
	my ( 
	$self,
	$onto, 
	$out_path, # file path for writing 
	$mode # 'rdfs' | 'owl'
	) = @_;
	my $class_tag = "$mode:Class";
	my $fs = '_'; # for id conversion from OBO to URI
	my %buffers; # rdf_id => buffer
	my $buffer = '';
	my $uris = \%uris;
	my $OUT = open_write ( $out_path );
	
	# ------------- Preamble: namespaces -------------------------------
	### Preambule of RDF file
	$buffer = write_rdf_preambule ( $uris,  );

	### Properties
	$buffer .= <<BFR;
	
	<!--
	///////////////////////////////////////////////////////////////////////////////////////
	//
	// Properties
	//
	///////////////////////////////////////////////////////////////////////////////////////
	-->
BFR
	
	print $OUT $buffer; $buffer = "";
	
	# ----------------------- ID mapping -------------------------------		
# 	my $id_map = map_rel_ids ( \@all_relationship_types, \@rel_name_spaces, $DFNS,  );
	my $id_map = map_rel_ids ( $onto  ); # print  Dumper($id_map);
	my @all_relationship_types = values(%{$onto->{RELATIONSHIP_TYPES}}); # objects 'OBO::Core::RelationshipType'
	# ------------------------------------------------------------------
	foreach my $relationship_type (@all_relationship_types) {
		my $obo_id = $relationship_type->id();
		next if $obo_id eq 'is_a';
		my $rdf_id = $id_map->{$obo_id};
		croak "Bad RDF id: $rdf_id" unless $rdf_id =~ /^(\w+?)_(\S+)$/xms ; # TODO move out of the loop
		my $NS = $1;
		my $subid = $2;
		my $ns = set_ns ( lc $NS, \%uris );
		
		my $uri = $uris->{$ns}; # with a trailing '/' or '#'
		my $buffer;			
		$buffer .= "\n\n\t<!-- $uri$rdf_id -->\n\n";
		$buffer .= "\t<owl:ObjectProperty rdf:about=\"&$ns;$rdf_id\">\n";
		$buffer .= "\t\t<rdf:type rdf:resource=\"&owl;SymmetricProperty\"/>\n" if ($relationship_type->is_symmetric() == 1);
		$buffer .= "\t\t<rdf:type rdf:resource=\"&owl;TransitiveProperty\"/>\n" if ($relationship_type->is_transitive() == 1);
		# not in biorel:
		# $buffer .= "\t\t<rdf:type rdf:resource=\"&owl;CyclicProperty\"/>\n" if ($relationship_type->is_cyclic() == 1);
		# not supported by owl 1:
		# $buffer .= "\t\t<rdf:type rdf:resource=\"&owl;AntiSymmetricProperty\"/>\n" if ($relationship_type->is_anti_symmetric() == 1);
		# $buffer .= "\t\t<rdf:type rdf:resource=\"&owl;ReflexiveProperty\"/>\n" if ($relationship_type->is_reflexive() == 1);
		# ------------------------ name ----------------------------
		if (defined $relationship_type->name()) {
			$buffer .= "\t\t<skos:prefLabel>".&char_http($relationship_type->name())."</skos:prefLabel>\n";
		} else {
			$buffer .= "\t</skos:prefLabel>\n"; # close the relationship type tag! (skipping the rest of the data, contact those guys)
			next;
		}
		# ------------------------- is_a ---------------------------
		my $rt = $onto->get_relationship_type_by_id('is_a');
		if (defined $rt)  {
			my @heads = @{$onto->get_head_by_relationship_type($relationship_type, $rt)};
			foreach my $head (@heads) {
				my $head_id = $head->id();
				my $rdf_id = $id_map->{$head_id};
				$buffer .= "\t\t<rdfs:subPropertyOf rdf:resource=\"&$ns;$rdf_id\"/>\n";
			}
		}
		# -------------------------- def -------------------------------
		if (defined $relationship_type->def()->text()) {
			$buffer .= "\t\t<skos:definition>".&char_http($relationship_type->def()->text())."</skos:definition>\n";
		}
		# ----------------------- xref -----------------------------
		my @sorted_xrefs = __sort_by(sub {lc(shift)}, sub { OBO::Core::Dbxref::as_string(shift) }, $relationship_type->xref_set_as_string());
		foreach my $xref (@sorted_xrefs) {
			$buffer .= "\t\t<skos:relatedMatch>".$xref->db().':'.$xref->acc()."</skos:relatedMatch>\n";
		}
		# ------------------------- namespace ----------------------
		foreach my $nspace ($relationship_type->namespace()) {
			# seems empty
			$buffer .= "\t\t<oboInOwl:hasOBONamespace>$nspace</oboInOwl:hasOBONamespace>\n";
		}
		# ---------------------- id --------------------------------
		$buffer .= "\t\t<oboInOwl:id>$obo_id</oboInOwl:id>\n";
		# ----------------------- synonym ------------------------------
		# TODO other types of synonyms
		foreach my $synonym ($relationship_type->synonym_set()) {
			my $scope = $synonym->scope();
			my $text = &char_http($synonym->def()->text());			
			if ( $scope eq 'EXACT' ) {
				$buffer .= "\t\t<skos:altLabel>$text</skos:altLabel>\n";
			}
		}
		# ----------------------- comment ------------------------------
		if(defined $relationship_type->comment()){
			$buffer .= "\t\t<rdfs:comment>".&char_http($relationship_type->comment())."</rdfs:comment>\n"; # sic !
		}
		# ----------------------- inverse_of ---------------------------
		my $ir = $relationship_type->inverse_of();
		if (defined $ir) {
			$buffer .= "\t\t<owl:inverseOf rdf:resource=\"&$ns;$id_map->{$ir->id()}\"/>\n";
		}
		# ----------------- transitive_over ----------------------------
		foreach my $transitive_over ($relationship_type->transitive_over()->get_set()) {
			my ( $obo_id2, $rel_name2 ) = split / ! /, $transitive_over;
			my $rdf_id2 = $id_map->{$obo_id2};
			$buffer .= "\t\t<owl:propertyChainAxiom rdf:parseType=\"Collection\">\n";
			$buffer .= "\t\t\t<rdf:Description rdf:about=\"&$ns;$rdf_id\"/>\n";
			my ( $ns, $subid ) = split_id ( $rdf_id2, '_' );
			$buffer .= "\t\t\t<rdf:Description rdf:about=\"&$ns;$rdf_id2\"/>\n";
			$buffer .= "\t\t</owl:propertyChainAxiom>\n";
		}
		# ------------------ holds_over_chain --------------------------
		foreach my $holds_over_chain ($relationship_type->holds_over_chain()) {
			my ( $rdf_id1, $rdf_id2 ) = ( $id_map->{@{$holds_over_chain}[0]}, $id_map->{@{$holds_over_chain}[1]} );
			$buffer .= "\t\t<owl:propertyChainAxiom rdf:parseType=\"Collection\">\n";
			my ( $ns, $subid );
			( $ns, $subid ) = split_id ( $rdf_id1, '_' );
			$buffer .= "\t\t\t<rdf:Description rdf:about=\"&$ns;$rdf_id1\"/>\n";
			( $ns, $subid ) = split_id ( $rdf_id2, '_' );
			$buffer .= "\t\t\t<rdf:Description rdf:about=\"&$ns;$rdf_id2\"/>\n";
			$buffer .= "\t\t</owl:propertyChainAxiom>\n";
		}
		# domain
		foreach my $domain ($relationship_type->domain()->get_set()) {
			$domain =~ /\A(\w+):(\S+)/xms; # sic!
			my ( $NS, $subid ) = ( $1, $2 );
			my $ns = lc $NS;
			$ns = $uris{ns} ? $ns : 'obo';
			$ns = $id_map->{$ns} if $id_map->{$ns};
			$buffer .= "\t\t<rdfs:domain rdf:resource=\"&$ns;$NS$fs$subid\"/>\n";
		}
		# range
		foreach my $range ($relationship_type->range()->get_set()) {
			#~ $buffer .= "\t\t<",$ns,':range>', $range, '</',$ns,":range>\n";
			$range =~ /\A(\w+):(\S+)/xms;
			my ( $NS, $subid ) = ( $1, $2 );
			my $ns = lc $NS;
			$ns = $uris{ns} ? $ns : 'obo';
			$buffer .= "\t\t<rdfs:range rdf:resource=\"&$ns;$NS$fs$subid\"/>\n";
		}

		$buffer .= "\t</owl:ObjectProperty>\n";
		# -------------------------- Axiom -----------------------------
		if (defined $relationship_type->def()->text()) {
			$buffer .= "\t<owl:Axiom>\n";
			for my $ref ($relationship_type->def()->dbxref_set()->get_set()) {
				$buffer .= "\t\t<skos:relatedMatch>".$ref->db().':'.$ref->acc()."</skos:relatedMatch>\n";
			}
			$buffer .= "\t\t<owl:annotatedTarget>".&char_http($relationship_type->def()->text())."</owl:annotatedTarget>\n";
			$buffer .= "\t\t<owl:annotatedSource rdf:resource=\"&$ns;$rdf_id\"/>\n";
# 			$buffer .= "\t\t<owl:annotatedProperty rdf:resource=\"&obo;IAO_0000115\"/>\n";
			$buffer .= "\t\t<owl:annotatedProperty rdf:resource=\"&skos;definition\"/>\n";
			$buffer .= "\t</owl:Axiom>\n";
		}
		
		# 
		# end of relationship type
		#
		$buffers{$rdf_id} = $buffer;
	}
	map { print $OUT $buffers{$_} } sort keys %buffers; %buffers = ();	
	
######################### Not used #####################################
		#~ my $buffer;
		#~ # functional
		#~ $buffer .= "\t\t<",$ns,':functional>true</',$ns,":functional>\n" if ($relationship_type->functional() == 1);
		#~ # inverse_functional
		#~ $buffer .= "\t\t<",$ns,':inverse_functional>true</',$ns,":inverse_functional>\n" if ($relationship_type->inverse_functional() == 1);
		#~ # alt_id
		#~ foreach my $alt_id ($relationship_type->alt_id()->get_set()) {
			#~ $buffer .= "\t\t<",$ns,':alt_id>', $alt_id, '</',$ns,":alt_id>\n";
		#~ }
		#~ # subset
		#~ foreach my $sset_name ($relationship_type->subset()) {
			#~ if ($onto->subset_def_map()->contains_key($sset_name)) {
				#~ $buffer .= "\t\t<$ns:subset>",$sset_name,"</$ns:subset>\n";
			#~ } else {
				#~ carp "\nThe relationship type ", $relationship_type->id(), " belongs to a non-defined subset ($sset_name).\nYou should add the missing subset definition.\n";
			#~ }
		#~ }
		#~ # is_class_level
		#~ $buffer .= "\t\t<",$ns,':is_class_level>true</',$ns,":is_class_level>\n" if ($relationship_type->is_class_level() == 1);
		#~ $buffer = "";

########################################################################		

	#######################################################################
	#
	# Terms
	#
	#######################################################################
	
	$buffer .= "\n\t<!--\n";
	$buffer .= "\t///////////////////////////////////////////////////////////////////////////////////////\n";
	$buffer .= "\t//\n";
	$buffer .= "\t// Classes\n";
	$buffer .= "\t//\n";
	$buffer .= "\t///////////////////////////////////////////////////////////////////////////////////////\n";
	$buffer .= "\t-->\n";
	print $OUT $buffer; $buffer = "";
	my $special_cases = {'sio' => 1};
	my @all_terms = @{$onto->get_terms_sorted_by_id()};
	foreach my $term (@all_terms) {
		my $term_id = $term-> id();
		my ($rdf_id, $ns) = set_rdf_class_id ( $term_id, $special_cases );
		my $buffer;
		my $uri = $uris->{$ns};
		$buffer .= "\n\n\t<!-- $uri$rdf_id -->\n\n";

		$buffer .= "\t<$class_tag rdf:about=\"&$ns;$rdf_id\">\n";		
		# ------------------- name -------------------------------------
		my $term_name = $term->name();
		my $term_name_to_print = (defined $term_name)?$term_name:'no_name';
		$buffer .= "\t\t<skos:prefLabel>".&char_http($term_name_to_print)."</skos:prefLabel>\n";
		# -------------------- is_a ------------------------------------
		
		my $rt = $onto->get_relationship_type_by_id('is_a');
		if (defined $rt)  {
			my %saw_is_a; # avoid duplicated arrows (RelationshipSet?) Does it make sense?
			my @heads = @{$onto->get_head_by_relationship_type($term, $rt)};
			#~ foreach my $head (grep {!$saw_is_a{$_}++} @heads) {
			foreach my $head ( @heads ) {
				my $head_id = $head->id();
				my ($rdf_id, $ns) = set_rdf_class_id ( $head_id, $special_cases );
				$buffer .= "\t\t<rdfs:subClassOf rdf:resource=\"&$ns;$rdf_id\"/>\n";
			}
		}
		# ------------------ relationship ------------------------------
		foreach my $rt ( @{$onto->get_relationship_types()} ) {
			my $obo_rid = $rt->id();
			if ($obo_rid && $obo_rid ne 'is_a') { # is_a is printed above
				my $rdf_rid = $id_map->{$obo_rid};
				$rdf_rid =~ /\A(\w+)_(\S+)/xms;
				my ( $RNS, $subid ) = ( $1, $2 );
				my $rns = set_ns (lc $RNS, \%uris);
				my %saw_rel; # avoid duplicated arrows (RelationshipSet?)
				my @heads = @{$onto->get_head_by_relationship_type($term, $rt)};
				#~ foreach my $head (grep {!$saw_is_a{$_}++} @heads) {
				foreach my $head ( @heads ) {	
					my $head_id = $head->id();
					my ($rdf_id, $ns) = set_rdf_class_id ( $head_id, $special_cases );
					if ( $mode eq 'rdfs' ) {
						$buffer .= "\t\t<$rns:$rdf_rid rdf:resource=\"&$ns;$rdf_id\"/>\n";
					} elsif ( $mode eq 'owl' ) {
						$buffer = write_prop ( $buffer, $rns, $rdf_rid, $ns, $rdf_id );
					}
				}
			}
		} # end of foreach
		# ------------------------- id ---------------------------------
		$buffer .= "\t\t<oboInOwl:id>$term_id</oboInOwl:id>\n";
		# -------------------------- def -------------------------------
		if (defined $term->def()->text()) {
			$buffer .= "\t\t<skos:definition>".&char_http($term->def()->text())."</skos:definition>\n";
		}
		# ---------------------- xref ----------------------------------
		my @sorted_xrefs = __sort_by(sub {lc(shift)}, sub { OBO::Core::Dbxref::as_string(shift) }, $term->xref_set_as_string());
		foreach my $xref (@sorted_xrefs) {
			$buffer .= "\t\t<skos:relatedMatch>".$xref->db().':'.$xref->acc()."</skos:relatedMatch>\n";
		}
		# ----------------------- synonym ------------------------------
		foreach my $synonym ($term->synonym_set()) {
			my $scope = $synonym->scope();
			my $text = &char_http($synonym->def()->text());			
			if ( $scope eq 'EXACT' ) {
				$buffer .= "\t\t<skos:altLabel>$text</skos:altLabel>\n";
			}
		}
		# ---------------------------- subset --------------------------
		## commented because something is wrong with $ns
		## should be go#subset_name instead of obo#subset_name
# 		foreach my $sset_name ($term->subset()) {
# 			if ($onto->subset_def_map()->contains_key($sset_name)) {
# 				$buffer .= "\t\t<oboInOwl:inSubset rdf:resource=\"&$ns;$ns#$sset_name\"/>\n";
# 			} else {
# 				carp "\nThe term ", $term->id(), " belongs to a non-defined subset ($sset_name).\nYou should add the missing subset definition.\n";
# 			}
# 		}
		# ---------------------------- namespace --------------------------
		foreach my $ns ($term->namespace()) {
			$buffer .= "\t\t<oboInOwl:hasOBONamespace>$ns</oboInOwl:hasOBONamespace>\n";
		}
		
		$buffer .= "\t</$class_tag>\n";
		# -------------------------- Axiom -----------------------------
		## commented because some xrefs to defs in GO contain uris; the culprit is most like the '&' char
# 		if (defined $term->def()->text()) {
# 			$buffer .= "\t<owl:Axiom>\n";
# 			for my $ref ($term->def()->dbxref_set()->get_set()) {
# 				$buffer .= "\t\t<skos:relatedMatch>".$ref->db().':'.$ref->acc()."</skos:relatedMatch>\n";
# 			}
# 			$buffer .= "\t\t<owl:annotatedTarget>".&char_http($term->def()->text())."</owl:annotatedTarget>\n";
# 			$buffer .= "\t\t<owl:annotatedSource rdf:resource=\"&$ns;$rdf_id\"/>\n";
# 			$buffer .= "\t\t<owl:annotatedProperty rdf:resource=\"&skos;definition\"/>\n";
# 			$buffer .= "\t</owl:Axiom>\n";
# 		}
		$buffers{$rdf_id} = $buffer;
	}
	map { print $OUT $buffers{$_} } sort keys %buffers;	%buffers = ();

		
# ----------------------------------------------------------------------
# copy from rel types:
		#~ $buffers{$rdf_id} = $buffer;
			#~ $buffer .= "\t<owl:Axiom>\n";
			#~ for my $ref ($relationship_type->def()->dbxref_set()->get_set()) {
				#~ $buffer .= "\t\t<skos:relatedMatch>".$ref->db().':'.$ref->acc()."</skos:relatedMatch>\n";
			#~ }
			#~ $buffer .= "\t\t<owl:annotatedTarget>".&char_http($relationship_type->def()->text())."</owl:annotatedTarget>\n";
			#~ $buffer .= "\t\t<owl:annotatedSource rdf:about=\"&$ns;$rdf_id\">\n";
			#~ $buffer .= "\t\t<owl:annotatedProperty rdf:resource=\"&obo;IAO_0000115\"/>\n";
			#~ $buffer .= "\t</owl:Axiom>\n";

############################## Not used ################################
		#~ # ------------------------ alt_id ------------------------------
		#map	{$buffer .= "\t\t<$ns:hasAlternativeId>$_</$ns:hasAlternativeId>\n"} ($term->alt_id()->get_set());
		#~ # ---------------------- property_value ------------------------
		#~ my @property_values = sort {$a->id() cmp $b->id()} $term->property_value()->get_set();
		#~ foreach my $value (@property_values) {
			#~ if (defined $value->head()->instance_of()) {
				#~ $buffer .= "\t\t<$ns:property_value>\n";
				#~ $buffer .= "\t\t\t<rdf:Description>\n";
					#~ $buffer .= "\t\t\t\t<$ns:property>", $value->type(),'</',$ns,":property>\n";
					#~ $buffer .= "\t\t\t\t<$ns:value rdf:type=\"",$value->head()->instance_of()->id(),"\">", $value->head()->id(),'</',$ns,":value>\n";
				#~ $buffer .= "\t\t\t</rdf:Description>\n";
				#~ $buffer .= "\t\t</$ns:property_value>";
			#~ } else {
				#~ $buffer .= "\t\t<$ns:property_value>\n";
				#~ $buffer .= "\t\t\t<rdf:Description>\n";
					#~ $buffer .= "\t\t\t\t<$ns:property>", $value->type(),'</',$ns,":property>\n";
					#~ $buffer .= "\t\t\t\t<$ns:value>", $value->head()->id(),'</',$ns,":value>\n";
				#~ $buffer .= "\t\t\t</rdf:Description>\n";
				#~ $buffer .= "\t\t</$ns:property_value>";
			#~ }
		#~ }
		
		
		# ------------------------ end of term -------------------------

	#######################################################################
	#
	# instances
	#
	#######################################################################
	my @all_instances = @{$onto->get_instances_sorted_by_id()};
	foreach my $instance (@all_instances) {
		# TODO export instances
	}
	# -------------------------- EOF -----------------------------------
	$buffer .= "</rdf:RDF>\n\n";
	$buffer .= "<!--\nGenerated with: ".$0.", ".__date()."\n-->";
	print $OUT $buffer;
	close $OUT;
	return $id_map;
}

sub new {
	my $class = shift;
	my $self = {};
	bless ( $self, $class );
	return $self;
}

sub __sort_by {
	caller eq __PACKAGE__ or croak;
	my ($subRef1, $subRef2, @input) = @_;
	my @result = map { $_->[0] }                           # restore original values
				sort { $a->[1] cmp $b->[1] }               # sort
				map  { [$_, &$subRef1($_->$subRef2())] }   # transform: value, sortkey
				@input;
}

sub __sort_by_id {
	caller eq __PACKAGE__ or croak;
	my ($subRef, @input) = @_;
	my @result = map { $_->[0] }                           # restore original values
				sort { $a->[1] cmp $b->[1] }               # sort
				map  { [$_, &$subRef($_->id())] }          # transform: value, sortkey
				@input;
}

sub __get_name_without_whitespaces() {
	caller eq __PACKAGE__ or croak;
	$_[0] =~ s/\s+/_/g;
	return $_[0];
}

sub set_rdf_class_id {
	my (
	$term_id, 
	$exceptions # ref to a hash like: {'sio' => 1}
	) = @_;
	my  $fs = '_';
	#~ $term_id =~ tr/[_\]/-/; # vlmir - trimming
	$term_id =~ /\A(\w+):(\S+)/xms;
	unless ( $1 && $2 ) {
		carp "Malformed ID $term_id: $!";
		return;
	}
	my $NS = $1;
	my $ns = lc $NS;
	my $subid = $2; # print "ns: $ns\n";
	$subid =~ s/\W/-/g; # vlmir - trimming
	my $rdf_id;
	if ( $uris{$ns} ) { # means not an OBO term
		$rdf_id =  $exceptions->{$ns} ? $NS.$fs.$subid : $subid; 
	} else {
		$rdf_id =  $NS.$fs.$subid;
		$ns = 'obo';
		
	}
	return ($rdf_id, $ns );
}


sub map_rel_ids {
	my ( 
	$onto,
	$fs # optional, defaults to '_'
	) = @_;
	my @all_relationship_types = values(%{$onto->{RELATIONSHIP_TYPES}}); # objects 'OBO::Core::RelationshipType'
	my $dfns = $onto->id() || $onto->get_terms_idspace(); # both 'go' for GO
	my $DFNS = uc $dfns;

	$fs ||= '_';
	my $id_map;
	foreach my $relationship_type ( @all_relationship_types ) {
		my $obo_id = $relationship_type->id();
		next if $obo_id eq 'is_a';
		my $rdf_id;
		my %xrefs; # e.g. ('RO' => '0002211')
		map {$xrefs{$_->db()} = $_->acc() }
			($relationship_type->xref_set_as_string()); # 'OBO::Core::Dbxref'
		foreach ( sort keys %xrefs ) { # the normal situation
			my ( $id ) = split /\s/, $xrefs{$_};
			$rdf_id =  $_.$fs.$id if $id; 
			last if $rdf_id; # the first found in the order 'BFO', 'RO', 'SIO'
		}
		unless ( $rdf_id ) { # less likely a situation
			$obo_id =~ /\A(\w+):(\S+)/xms;
			if ( $1 && $2 ) {
				$rdf_id =  $1.$fs.$2;
			} else { # exceptional situation - OBOF type id and no xrefs
				$rdf_id = $DFNS.$fs.$obo_id;
			}
		}
		$id_map->{$obo_id} = $rdf_id;
	}return $id_map;
}
	
sub split_id {
	my ( $id, $fs ) = @_;
	my ( $NS, $subid ) = split /$fs/, $id;
	my $ns = set_ns (lc $NS, \%uris);
	return ( $ns, $subid );
}

sub set_ns {
	my ( $ns, $uris ) = @_;
	$uris->{$ns} ? return $ns : return 'obo';
}

sub write_prop {
	my ( $buffer, $rns, $rdf_rid, $ns, $rdf_id ) = @_;
			$buffer .= "\t\t<rdfs:subClassOf>\n";
			$buffer .= "\t\t\t<owl:Restriction>\n";
			$buffer .= "\t\t\t\t<owl:onProperty rdf:resource=\"&$rns;$rdf_rid\"/>\n";
			$buffer .= "\t\t\t\t<owl:someValuesFrom rdf:resource=\"&$ns;$rdf_id\"/>\n";
			$buffer .= "\t\t\t</owl:Restriction>\n";
			$buffer .= "\t\t</rdfs:subClassOf>\n";
			return $buffer;
}

# my $rex_syns = qr/synonym:\s(.+?)\n/xmsgo; # syntax error, TODO fix it
# TODO make a generic function for any other field, not just 'synonym'
sub map2id {
	my ( 
	$self,
	$obo_file_path,
	$field_name, # e.g. 'synonym'
	$type, # e.g. 'Term'; optional
	) = @_;
	$type ||= 'Term'; # default value
	my $FH = open_read ( $obo_file_path );
	my $out;
	local $/ = "\n\n"; # splitting into stanzas
# synonym: "MOD_RES Phosphothreonine" EXACT UniProt-feature []
# synonym: "MOD_RES N-acetylthreonine" EXACT UniProt-feature []
# synonym: "LIPID O-palmitoyl threonine" EXACT UniProt-feature []
	my $rex_field = qr/^$field_name: /xmso;
	
	while ( <$FH> ) {
		my $entry = $_;
		next unless $entry =~ $rex_field;
		chomp $entry;
		my @lines = split /\n/, $entry;
		next unless "[$type]" eq $lines[0];
		my $obo_id = substr $lines[1], 4;
		my $name = substr $lines[2], 6;
		my ( $NS, $id ) = split /:/, $obo_id;
		$out->{$NS}{$id}{'name'} = $name;
		foreach my $line ( @lines[3..$#lines] ) {
			if ( (substr $line, 0, 4) eq 'def:' ) {
				$out->{$NS}{$id}{'def'} = $line =~ $rex_dblq ? $1 : carp "undefined Def for term $obo_id";
			} 
			elsif ( (substr $line, 0, 8) eq $field_name.':' ) {
				$line =~ $rex_dblq ? $out->{$field_name}{$1}{$NS}{$id} = $2 : next;
			}
		}
	}
	close $FH;
	return $out;
}
sub _syn2id {
	my ( 
	$self,
	$obo_file_path,
	$type, # e.g. 'Term'; optional
	) = @_;
	$type ||= 'Term'; # default value
	my $FH = open_read ( $obo_file_path );
	my $out;
	local $/ = "\n\n";
# synonym: "MOD_RES Phosphothreonine" EXACT UniProt-feature []
# synonym: "MOD_RES N-acetylthreonine" EXACT UniProt-feature []
# synonym: "LIPID O-palmitoyl threonine" EXACT UniProt-feature []
	my $rex_syns = qr/synonym/xmso;
	while ( <$FH> ) {
		my $entry = $_;
		chomp $entry;
		my @lines = split /\n/, $entry;
		next unless "[$type]" eq $lines[0];
		next unless $entry =~ $rex_syns;
		my $id = substr $lines[1], 4;
		my $name = substr $lines[2], 6;
		$out->{$id}{'name'} = $name;
		foreach my $line ( @lines[3..$#lines] ) {
			if ( (substr $line, 0, 4) eq 'def:' ) {
				$out->{$id}{'def'} = $line =~ $rex_dblq ? $1 : carp "undefined Def for term $id";
			} 
			elsif ( (substr $line, 0, 8) eq 'synonym:' ) {
				$line =~ $rex_dblq ? $out->{$1}{$id}++ : next;
			}
		}
	}
	close $FH;
	return $out;
}

sub write_rdf_preambule {
	my (
	$uris,
	) = @_;
	
	my $buffer = <<BFR;
<?xml version=\"1.0\"?>
<!DOCTYPE rdf:RDF [
BFR
	map { $buffer .= "\t<!ENTITY $_ \"$uris->{$_}\">\n"} sort keys %{$uris};
	$buffer .= <<BFR;
]>
<rdf:RDF
BFR
	map {$buffer .= "\txmlns:$_=\"$uris->{$_}\"\n"} sort keys %{$uris};
	$buffer .= "\t>\n";

	return $buffer;
}

1;
