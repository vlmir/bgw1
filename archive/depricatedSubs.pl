
############################ DEPRICATED #######################################
sub _test_rls {
	my ( $onto, $rls ) = @_;
	my %rltps;
	foreach ( keys %{$rls} ) {
		my $name = $rls->{$_}[1];
		my $rltp = $onto->get_relationship_type_by_name ( $name );
		croak "Relationship type: $name  not found in the ontology: $onto: $!" unless ( $rltp );
		$rltps{$_} = $rltp; # for future uses
	}
	return \%rltps;
}

sub _write_rdf_properties {
	# NOTE; namespaces absent in %uris converted to 'obo' ! Special case - SIO
	my (
	$uris,
	$rltps, # currently a ref to SharedVars::%rls
	$keys, # ref to an array of keys to be used in 
	) = @_;
	
	my $buffer = <<BFR;
	<!--
	///////////////////////////////////////////////////////////////////////////////////////
	//
	// Properties
	//
	///////////////////////////////////////////////////////////////////////////////////////
	-->
BFR

foreach ( @{$keys} ) {
		my ( $NS, $id, $label ) = @{ $rltps->{$_} };
		my $rdfid = $NS.'_'.$id;
		my $ns = lc ( $NS );
		my $uri;
		if ( $uris->{$ns} ) { # other than OBO
			$uri = $uris->{$ns};
			$rdfid = $id;
			$rdfid = $NS.'_'.$id if $ns eq 'sio';
		} 
		else {
			$rdfid = $NS.'_'.$id;
			$ns = 'obo';
			$uri = $uris->{$ns};
		}
		$buffer .= "\n\n\t<!-- $uri$rdfid -->\n\n";
		$buffer .= "\t<owl:ObjectProperty rdf:about=\"&$ns;$rdfid\">\n";
		$buffer .= "\t\t<skos:prefLabel>$label</skos:prefLabel>\n";
		$buffer .= "\t</owl:ObjectProperty>\n";
	}
	return $buffer;
}
sub set_typedefs {
	my ( 
	$onto, 
	$rls, # ref to SharedVars::%rls
	$keys # ref to an array s
	) = @_;
	## to prevent accidental modification of external vars
	my %rls = %{$rls};
	my @keys = @{$keys};
	
	my $tpdefs; # ref to a hash
	foreach my $key ( @keys ) {
		my $id = $rls{$key}->[1];
		$id =~ tr/ /_/; # OBO style Typedef id
		my $rltp = $onto->get_relationship_type_by_id ( $id );
		unless ( $rltp ) {
			$rltp = OBO::Core::RelationshipType->new();
			$rltp->id ( $id );
			$rltp->name ( $rls{$key}->[1] );
			$rltp->xref_set_as_string ("[$rls{$key}[0]]");
			$onto->add_relationship_type( $rltp );
		}
		$tpdefs->{$key} = $rltp;
	}
	return $tpdefs;	
}
############################# entrez2rdf #######################################

sub entrez2rdf {
	my (
	$self,
	$data, # output from parse_entrez
# 	$map, # mandatory,  # [gnid => [upacs]}
	$out_path, 
	) = @_;
	croak "Not enough arguments!" if ( @_ < 3 );
		
	my $uris = \%uris;
	my $fs = '_';
	my $buffer = '';

	my $OUT = open_write ( $out_path );
	
	### Preambule of RDF file
	$buffer = write_rdf_preambule ( $uris,  );

	### Properties
	$buffer .= write_rdf_properties ( $uris, \%rltps, \@rlskeys );
	
$buffer .= <<BFR;
	
	<!--
	///////////////////////////////////////////////////////////////////////////////////////
	//
	// Classes
	//
	///////////////////////////////////////////////////////////////////////////////////////
	-->
BFR
	print $OUT $buffer; $buffer = "";
	
	my $gn_prn = $prns{'gn'}[0];
	$gn_prn =~ tr/:/_/;

	foreach my $gnid ( sort keys %{$data->{'GENES'}{$gnk}} ) {
		my $gn = $data->{'GENES'}{$gnk}{$gnid};
		print $OUT  "\n\n\t<!--$uris->{'ncbigene'}$gnid -->\n\n";
		print $OUT "\t<rdfs:Class rdf:about=\"&$gnns;$gnid\">\n";
		print $OUT "\t\t<rdfs:subClassOf rdf:resource=\"&sio;$gn_prn\"/>\n"; # TODO extract namespaces (e.g. 'sio') from IDs
		map { print $OUT "\t\t<skos:prefLabel>".&char_http($_)."</skos:prefLabel>\n";} sort keys %{$gn->{$symbk}};
		map { print $OUT "\t\t<skos:definition>".&char_http($_)."</skos:definition>\n";} sort keys %{$gn->{$dscrk}};
		my ( $NS, $id ) = @{$rltps{'bml2txn'}};
		map  { print $OUT "\t\t<obo:$NS$fs$id rdf:resource=\"&obo;$TXNNS$fs$_\"/>\n";} sort { $a <=> $b } keys %{$gn->{$txnk}};
		( $NS, $id ) = @{$rltps{'gn2prd'}};
		map  { print $OUT "\t\t<sio:$NS$fs$id rdf:resource=\"&uniprot;$_\"/>\n";} sort keys %{$gn->{$upack}};
		my $vals;
		$vals = $gn->{$synmk};
		## &char_http is needed because of synonyms like p34<CDC2> 
		map { print $OUT "\t\t<skos:altLabel>".&char_http($_)."</skos:altLabel>\n" if $_ ne '-'; } sort keys %{$vals}; 
		$vals = $gn->{$engnk};
		map { print $OUT "\t\t<skos:relatedMatch>$nss{ens}:$_</skos:relatedMatch>\n" if $_ ne '-'; } sort keys %{$vals};
		
		# the code below retrieves all annotations as data properties; currently only ENSEMBL used
# 		my %select_keys = ( $engnk => 1, );
# 		foreach my $key ( sort keys %{$gn} ) {
# 			next unless $select_keys{$key};
# 			my $vals = $gn->{$key};
# 			#~ map { print $OUT "\t\t<ssb:$key>$_</ssb:$key>\n"; } sort keys %{$vals};
# 			map { print $OUT "\t\t<ssb:$key>$_</ssb:$key>\n" if $_ ne '-'; } sort keys %{$vals}; # TODO get rid of 'ssb'
# 		}
		print $OUT "\t</rdfs:Class>\n"; # complete
	}
	print $OUT "</rdf:RDF>\n";
	print $OUT "<!--Generated with: $0, ".__date."-->";
	
	close $OUT;
}
sub gpa2rdf {
# Note: rdf:bag is used to provide resolvable URIs
	my ( 
	$self,
	$data, # output from parse_gpa()
	$rdf_path, # for writing
	) = @_;
	croak "Not enough arguments!" if ( @_ < 3 );
	
		
	my $uris = \%uris;
	my $rltps = \%rltps;
	my $fs = '_';
	my $buffer = '';

	my $OUT = open_write ( $rdf_path );
	
	### Preambule of RDF file
	$buffer = write_rdf_preambule ( $uris,  );

	### Properties
	$buffer .= write_rdf_properties ( $uris, $rltps, \@rlskeys );
		
	$buffer .= <<BFR;
	<!--
	///////////////////////////////////////////////////////////////////////////////////////
	//
	// Statements
	//
	///////////////////////////////////////////////////////////////////////////////////////
	-->
BFR
	print $OUT $buffer; $buffer = "";

########################################################################
	
	my $goa_class = 'SIO_000897'; # 'association'
	my $src = $prtSrc;
	# TODO generalize to use sources other than UP ??
	# this will minimize hard coding ( now $prtSrc (UniProtKB) is used )
	my $prts = $data->{'Proteins'}{$src};

	foreach my $upac ( sort keys %{$prts} ) {
		my $bag_bfr;
		print $OUT  "\n\n\t<!-- $uris->{'uniprot'}$upac -->\n\n";
		$bag_bfr = <<BFR;
	<rdf:Bag rdf:about="&goa;$upac">
BFR
		my $rel_bfr = <<BFR;
	<rdf:Description rdf:about="&uniprot;$upac">
BFR
		# associations
		my $asns = $prts->{$upac}{$GOANS};
			foreach my $asnid (sort keys %{$asns} ) {
				my $asn = $data->{$GOANS}{$asnid};
				my $qlfr = $asn->{'qualifier'}; # OBO rel ID
				my $goaid = "GOA$fs$asnid";
				my $goid = $asn->{$GONS}; #print Dumper($rels);
				my ( $NS, $id ) = @{ $rltps->{$tdid2key{$qlfr}} };
				my $relid = $NS.$fs.$id;
				my $objectid = $asn->{'UniProtKB'};
				$bag_bfr .= "\t\t<rdf:li rdf:resource=\"&ssb;$goaid\"/>\n";
				#~ $bag_bfr .= "\t\t<rdf:li rdf:resource=\"_:$goaid\"/>\n"; # did not convert to blank node ids
				my $buffer;
				$buffer .= "\t<rdf:Statement rdf:about=\"&ssb;$goaid\">\n";
				#~ $buffer .= "\t<rdf:Statement rdf:about=\"_:$goaid\">\n"; # these were OK
				$buffer .= "\t\t<rdfs:subClassOf rdf:resource=\"&sio;$goa_class\"/>\n";
				$buffer .= "\t\t<rdf:subject rdf:resource=\"&uniprot;$upac\"/>\n";
				$buffer .= "\t\t<rdf:predicate rdf:resource=\"&obo;$relid\"/>\n";
				$buffer .= "\t\t<rdf:object rdf:resource=\"&obo;$GONS$fs$goid\"/>\n";
				my ( @keys, $property );
# 				$property = 'isoform';
				$buffer .= "\t\t<skos:relatedMatch>$nss{prt}:$objectid</skos:relatedMatch>\n" if $objectid ne $upac;
				@keys = sort keys %{$asn->{'PMID'}};
# 				$property = $pmns;
				map { $buffer .= "\t\t<skos:relatedMatch>$nss{pm}:$_</skos:relatedMatch>\n"; } @keys;
				@keys = sort keys %{$asn->{'ECO'}}; # changed
# 				$property = $econs;
# 				map { $buffer .= "\t\t<$ssb:$property>$_</$ssb:$property>\n"; } @keys;
				map { $buffer .= "\t\t<skos:relatedMatch>ECO:$_</skos:relatedMatch>\n"; } @keys;
				@keys = sort keys %{$asn->{$host}};
# 				$property = $host;
				map { $buffer .= "\t\t<skos:relatedMatch>$nss{txn}:$_</skos:relatedMatch>\n"; } @keys;
				#~ $buffer .= "\t\t<$ssb:namespace>$goans</$ssb:namespace>\n";
				#~ $buffer .= "\t\t<$ssb:id>$goaid</$ssb:id>\n";
				# flushing
				$buffer .= "\t</rdf:Statement>\n";
				print $OUT $buffer;
				$rel_bfr .= "\t\t<obo:$relid rdf:resource=\"&obo;$GONS$fs$goid\"/>\n";
			} # foreach asnid
		$bag_bfr .= "\t</rdf:Bag>\n";
		$rel_bfr .= "\t</rdf:Description>\n";
		print $OUT $bag_bfr;
		print $OUT $rel_bfr;
		} # foreach upac
	print $OUT "</rdf:RDF>\n";
	print $OUT "<!--Generated with: ".$0.", ".__date."-->";
	close $OUT;
	return $OUT;
}
sub intact2rdf {
	# expects all the necessary filtering done before
	# generates an rdf file for IntAct data
	my (
	$self,
	$data, # output from parse_tab()
	$rdf_file,
	) = @_;
	croak "Not enough arguments!" if ( @_ < 3 );

	my $uris = \%uris;
	my $rltps = \%rltps;
	my $fs = '_';
	my $buffer = '';
	my $OUT = open_write ( $rdf_file );
	
	### Preambule of RDF file
	$buffer = write_rdf_preambule ( $uris,  );
	
	### Properties
	$buffer .= write_rdf_properties ( $uris, $rltps, \@rlskeys );
	
$buffer .= <<BFR;
	<!--
	///////////////////////////////////////////////////////////////////////////////////////
	//
	// Classes
	//
	///////////////////////////////////////////////////////////////////////////////////////
	-->
BFR
	print $OUT $buffer; $buffer = "";

	# parent term
	# currently: http://purl.obolibrary.org/obo/MI_0000
	my $ppi_prn = $prns{'ppi'}[0];
	$ppi_prn =~ tr/:/_/;

	my $irns = $data->{$irnk}{$ppiSrc};
	my ( $NS, $id ) = @{$rltps{'ppi2prt'}};
	foreach my $irnid ( sort keys %{$irns} ) {
		my $irn = $irns->{$irnid};
		print $OUT  "\n\n\t<!-- $uris->{'intact'}$irnid -->\n\n";
		print $OUT "\t<rdfs:Class rdf:about=\"&$ppins;$irnid\">\n";		
		print $OUT "\t\t<rdfs:subClassOf rdf:resource=\"&obo;$ppi_prn\"/>\n";
		
		# TODO fix MI ids in parse_tab(), now just a quick fix
		# Interaction type
		my $irtps = $irn->{$irtpk};
		map { $_ =~tr/:/_/; print $OUT "\t\t<rdfs:subClassOf rdf:resource=\"&obo;$_\"/>\n"; } sort keys %{$irtps};	
		# Note: the modeling belos is according to the modeling in MI - interaction type part_of molecular interaction but is rather cryptic
		#~ map { $_ =~tr/:/_/; print $OUT "\t\t<sio:$rls{'mi2itp'} rdf:resource=\"&obo;$_\"/>\n"; } sort keys %{$irtps};		
			
		# the tab file has no interaction names
		print $OUT "\t\t<skos:prefLabel>$PPINS $irnid protein-protein interaction</skos:prefLabel>\n";
		
		my $prts = $irn->{$prtk}{$prtSrc};
		map { print $OUT  "\t\t<sio:$NS$fs$id rdf:resource=\"&$prtns;$_\"/>\n"; } sort keys %{$prts};
		
		# Detection method	
		## TODO find a suitable property
# 		my $mths = $irn->{$mthk};
# 		map { $_ =~tr/:/_/; print $OUT "\t\t<$ssb:detectionMethod rdf:resource=\"&obo;$_\"/>\n"; } sort keys %{$mths};
		
		# Experimental role
		# TODO implement
		#~ my $role = $data->{$prtk}{$prtSrc}{$bPrimId}{$ppiSrc}{$ppiPrimId}{$exrlk}{$2};
		
		# PubMed (many entries have as well 'imex' as xref, but this is not a publication)
		my $pbls = $irn->{$pblk}{$pblSrc}; # PubMed ref provided for every entry in IntAct
# 		map { print $OUT "\t\t<$ssb:$pmns>$_</$ssb:$pmns>\n"; } sort keys %{$pbls};
		map { print $OUT "\t\t<skos:relatedMatch>$nss{pm}:$_</skos:relatedMatch>\n"; } sort keys %{$pbls};
		
# 		print $OUT "\t\t<$ssb:namespace>$ppins</$ssb:namespace>\n";	
# 		print $OUT "\t\t<$ssb:id>$irnid</$ssb:id>\n";	
		print $OUT "\t</rdfs:Class>\n";		
	}
	print $OUT "</rdf:RDF>\n";
	print $OUT "<!--Generated with $0 ".__date."-->\n";	
	close $OUT;
}

sub set_rel_types {
	## new rel types are addted to $onto if not present
	my ( $onto, $rels ) = @_;
	my %rels = %{$rels}; # making sure $rels is never modified
	my $rltps;
	foreach my $rel ( keys %rels ) {
		my $rltp = $onto->get_relationship_type_by_id ( $rel );
		unless ( $rltp ) {
			$rltp = OBO::Core::RelationshipType->new();
			$rltp->id ( $rel );
			$rltp->name ( $rel );
			$rltp->xref_set_as_string ("[$rels{$rel}[0]]");
			$onto->add_relationship_type( $rltp );
		}
		$rltps->{$rel} = $rltp;
	}
	return $rltps;
}

# 
# sub filter_goa_by_aspect {
# 	my ($in_file, $out_file, $aspect) = @_;
# 	croak "Not enough arguments!" if !($in_file and $out_file and $aspect);
# 	open my $IN, '<',  $in_file || croak "The file '$in_file' couldn't be opened: $!";
# 	open my $OUT, '>',  $out_file || croak "The file '$out_file' couldn't be opened: $!";
# 	while (<$IN>) {
# 		chomp;
# 		next if /\A!/xms; # !gaf-version: 2.0
# 		my @assoc = split(/\t/);
# 		foreach(@assoc){
# 			$_ =~ s/^\s+//;
# 			$_ =~ s/\s+$//;
# 		}
# 		print $OUT "$_\n" if ($assoc[8] eq $aspect);
# 	}
# 	close $IN;
# 	close $OUT;
# }
# 
# sub filter_up_by_taxon {
# 	# Note: the output of this sub contains many fragments unlike get_fasta()
# 	my (
# 	$infiles, # ref to an array of data file full paths
# 	$taxon, # NCBI_TaxID
# 	$dat_file, # UniProt .dat file
# 	$map, # ref { UPAC=>UPID ) for filtering, optional
# 	) = @_;
# 	open my $DAT, '>', $dat_file or croak "File $dat_file cannot be opened: $!";	
# 	my %seen;
# 	foreach my $in_file ( @{$infiles} ) {
# 		open my $IN, '<', $in_file or croak "File: $in_file cannot be opened";
# 		local $/ = "\n//\n";
# 		# TODO test the new regexes
# 		my $rex_txid = qr/^OX\s{3}NCBI_TaxID=$taxon;/xmso;
# 		my $rex_ac = qr/^AC\s{3}(\w+)/xmso; # matches only the first AC
# # DE   Flags: Precursor; Fragment;
# # DE   Flags: Fragment;
# 		my $rex_frg = qr/^DE\s{3}Flags:\s.*?Fragment;.*?$/xmso;
# 		while (<$IN>) {
# # 			if ( /^OX\s+NCBI_TaxID=$taxon;/xms) {
# 			if ( $rex_txid ) {
# # 				my ( $ac ) = /^AC\s+(\w+)/xms; # matches only the first AC
# 				my ( $ac ) = $rex_ac;
# 				if ( $map ) {
# 					next unless $map->{$ac};
# 				}
# 				next if $rex_frg; # TODO to be tested
# 				next if $seen{$ac}; # a second entry with the same AC (happens)
# 				$seen{$ac}++;
# 				print $DAT "$_";
# 			}
# 		}		
# 	}
# 	close $DAT;
# 	return \%seen;
# }
# 
# sub get_fasta {
# 	# generate FASTA files
# 	# optionally saves to a file map UPAC => UPID	
# 	# Note: fragments of proteins are filtered out
# 	use SWISS::Entry;
# 	my (
# 	$in_file, 
# 	$taxon,
# 	$out_file,
# 	$map_file, # optional
# 	) = @_;
# 	open my $IN, '<', $in_file || croak "The file '$in_file' couldn't be opened: $!";
# 	open my $OUT, '>',  $out_file || croak "The file '$out_file' couldn't be opened: $!";
# 	my $MAP;
# 	if ( $map_file ) {
# 		open $MAP, '>',  $map_file || croak "The file '$map_file' couldn't be opened: $!";
# 	}
# 	local $/ = "\n//\n";
# 	while (<$IN>) {
# 		my $entry = SWISS::Entry->fromText($_);
# 		my $fasta = $entry->toFasta();
# 		my ($header_line, $seq) = $fasta =~ /\A(>.*?)$(.*)\z/xms; # \n is prepended to the sequence
# 		next if $header_line =~ /Fragment/; # not needed anymore - done in filter_up_by_taxon
# 		my ($header, $tail) = split /\s/, $header_line;
# 		my @fields = split /\|/, $header;
# 		print $OUT ">$taxon|$fields[1]|$fields[2]$seq";
# 		print $MAP "$fields[1]\t$fields[2]\n" if $map_file;
# 	}
# 	close $IN;
# 	close $OUT;
# 	close $MAP if $map_file;
# }
######################### from Intact #########################################
# sub parse_psimi {
# # this function is still very slow
# 	my (
# 		$self,
# 		$intact_files, # ref to a list of fully qualified paths
# 		$long_map, # complete UniProt map, to get rid of secondary UniPriot ACs
# 		$short_map # { UP AC => UP ID } ( optional ), map to filter by
# 	) = @_;	# print Dumper ( $intact_files );
# 	croak "No IntAct files to parse!\n" if ( ! $intact_files );
# 	# sharing results in an error even without threading:
# 	#~ my %data :shared; # Invalid value for shared scalar at /norstore/project/ssb/workspace/onto-perl/lib/OBO/Parser/IntActParser.pm line 135.
# 	#~ my %data; # works if no threading
# 	my $data; # ref to a hash;
# 	#~ my $data :shared; # ref to a hash; the same error
# 	my $count_accepted :shared = 0;
# 	my $count_rejected :shared = 0;
# 	my $no_full_name = 0;
# 	my $parser = XML::LibXML->new();
# 	foreach my $file_path ( @{$intact_files} ) {# print "file: $file_path\n";
# 
# 		#~ my $thr = async {
# 
# 		my $doc = XML::LibXML::XPathContext->new ( $parser->parse_file($file_path) ); # to deal with default namespace
# 		$doc->registerNs('x', 'http://psi.hupo.org/mi/mif');
# 				
# 		# bib ref
# 		# TODO retrieve pubmed ref from secondaryRef if it's there	
# 		my $bibrefdb = $doc->find ( 'x:entrySet/x:entry/x:source/x:bibref/x:xref/x:primaryRef/@db' )->to_literal->value;
# 		$bibrefdb eq 'pubmed' ?
# 		my $pubmedid = $doc->find ( 'x:entrySet/x:entry/x:source/x:bibref/x:xref/x:primaryRef/@id' )->to_literal->value :
# 		print "Primary bibref db: $bibrefdb\n";
# 		
# 		# interaction detection methods
# 		my @methods = $doc->findnodes ( 
# 		'/x:entrySet/x:entry/x:experimentList/x:experimentDescription/x:interactionDetectionMethod' );		
# 		if ( ! @methods ) {
# 			 carp "No methods in the file: $file_path! $!";
# 			 next;
# 		}
# 
# 		my @ppis = $doc->findnodes ( '/x:entrySet/x:entry/x:interactionList/x:interaction' );
# 		if ( ! @ppis ) {
# 			 carp "No ppis in the file: $file_path! $!";
# 			 next;
# 		}
# 		my $interactors = XML::LibXML::XPathContext->new ( $doc->findnodes ( '/x:entrySet/x:entry/x:interactorList/x:interactor' ) );
# 		$interactors->registerNs('x', 'http://psi.hupo.org/mi/mif');
# 		foreach ( @ppis ) {
# 			my $ppi = XML::LibXML::XPathContext->new ( $_ );
# 			$ppi->registerNs('x', 'http://psi.hupo.org/mi/mif');
# 			my @participants = $ppi->findnodes ( 'x:participantList/x:participant' );
# 
# 			# tagging ppis for including in $data
# 			my $map_hit = 0;
# 			# if a map is provided
# 			if ( $short_map ) {
# 				foreach ( @participants ) {
# 					my $participant = XML::LibXML::XPathContext->new ( $_ );
# 					$participant->registerNs('x', 'http://psi.hupo.org/mi/mif');
# 					my $interactor_id = $participant->find ( 'x:interactorRef' )->to_literal;
# 					# UniProt AC; participants without AC are ignored
# 					my $protein_id = $interactors->find ( '//x:interactor[@id = '.$interactor_id.']/x:xref/x:primaryRef/@id' );
# 					# searching for the first occurence of a core protein
# 					if ( $short_map->{$protein_id} ) {
# 						$map_hit++;
# 						last;
# 					}
# 				}
# 			}
# 			# if there is no map take all ppis
# 			else {
# 				$map_hit = 1;
# 			}
# 			$map_hit ? $count_accepted++ : $count_rejected++;
# 
# 			# filling up $data
# 			if ( $map_hit ) {
# 				# primary xrefs are used for identification because IntAct uses local IDs for ppis
# 				my $ppi_xref = $ppi->find ( 'x:xref/x:primaryRef/@id' )->to_literal; #'XML::LibXML::Literal'
# 				my $ref_db = $ppi->find ( 'x:xref/x:primaryRef/@db' )->to_literal;
# 				my $ppi_id;
# 				if ( $ref_db eq 'intact' ) {
# 					#~ $ppi_id = "$ref_db:$ppi_xref";
# 					$ppi_id = $ppi_xref;
# 				}else{
# 					carp "Rejected ppi with the primary xref $ref_db:$ppi_xref: $!"; # just a sanity check
# 					next;
# 				}
# 				#~ $data->{$ppi_id}{$irnmk} = $ppi->find ( 'x:names/x:shortLabel/text()' )->to_literal->value;
# 				my $shortLabel =  $ppi->find ( 'x:names/x:shortLabel/text()' )->to_literal->value;
# 				$data->{$ppi_id}{$irnmk} = $shortLabel; # "# Invalid value for shared scalar" no matter the value of $shortLabel in case of multithreading
# 				$data->{$ppi_id}{$irdek} = $ppi->find ( 'x:names/x:fullName/text()' )->to_literal->value or $no_full_name++;
# 				#~ $data->{$ppi_id}{$irdek} = 'not available'; 
# 				 
# 				#~ $data->{$ppi_id}{'interactionTypeId'} = $ppi->find ( 'x:interactionType/x:xref/x:primaryRef/@id' )->to_literal->value; # MI id
# 				
# 				my $ppiTypeId = $ppi->find ( 'x:interactionType/x:xref/x:primaryRef/@id' )->to_literal->value; # MI id
# 				my $ppiTypeName = $ppi->find ( 'x:interactionType/x:shortLabel/text()' )->to_literal->value;
# 				#~ $data->{$ppi_id}{$irtpk}{$ppiTypeId} = $ppiTypeName; # TODO fix me
# 				$data->{$ppi_id}{$irtpk}{$ppiTypeId} = 1;
# 				$data->{$ppi_id}{$PMNS}{$pubmedid} = 1;
# 				
# 				foreach ( @methods ) {
# 					my $method = XML::LibXML::XPathContext->new ( $_ );
# 					$method->registerNs('x', 'http://psi.hupo.org/mi/mif');
# 					my $methodid = $method->find ( 'x:xref/x:primaryRef/@id' )->to_literal->value;
# 					my $methodname = $method->find  ( 'x:names/x:shortLabel/text()' )->to_literal->value;
# 					$data->{$ppi_id}{'DetectionMethods'}{$methodid} = $methodname;
# 				}
# 
# 				
# 				foreach ( @participants ) {
# 					my $participant = XML::LibXML::XPathContext->new ( $_ );
# 					$participant->registerNs('x', 'http://psi.hupo.org/mi/mif');
# 					# internal IntAct interactor ID used for getting taxon ID and protein ID:
# 					my $interactor_id = $participant->find ( 'x:interactorRef/text()' )->to_literal;
# 					my $protein_id = $interactors->find ( '//x:interactor[@id = '.$interactor_id.']/x:xref/x:primaryRef/@id' )->to_literal->value;
# 					if ( $long_map->{$protein_id} ) {
# 						my $ncbi_id = $interactors->find ( '//x:interactor[@id = '.$interactor_id.']/x:organism/@ncbiTaxId' )->to_literal->value;
# 						# protein xref, tyically UniProt accession, any others??? TODO
# 						# for now ingnores any other sources, as well as secondary UniProt ACs
# 						$data->{$ppi_id}{$prtk}{$protein_id}{$PRTNS} = $long_map->{$protein_id};
# 						my $role_id = $participant->find ( 'x:experimentalRoleList/x:experimentalRole/x:xref/x:primaryRef/@id' )->to_literal->value; # experimental role
# 						my $role = $participant->find ( 'x:experimentalRoleList/x:experimentalRole/x:names/x:shortLabel/text()' )->to_literal->value; # experimental role
# 						$data->{$ppi_id}{$prtk}{$protein_id}{$exrlk}{$role_id} = $role;
# 						$data->{$ppi_id}{$prtk}{$protein_id}{$TXNNS} = $ncbi_id;
# 					} else { next; }
# 				} # end of foreach participant
# 			} # end of if $map_hit
# 		} # end of foreach interaction
# 		## } # end of async
# 		## print threads->list();
# 		## $thr->join(); # Global symbol "$thr" requires explicit package name at /norstore/project/ssb/workspace/onto-perl/lib/OBO/Parser/IntActParser.pm line 160.
# 
# 	} # end of foreach file
# 	print "Accepted ppis: $count_accepted, rejected ppis: $count_rejected, ppis without full name: $no_full_name\n" if $verbose;
# 	%{$data} ? return $data : carp 'No data to return';
# }
