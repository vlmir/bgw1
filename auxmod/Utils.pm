#!/usr/bin/perl
package Utils;

use Carp;
use strict;
use warnings;

# from: https://perlmaven.com/json
use 5.010; # needed even though perl 5.26 installed
# to install Cpanel::JSON::XS gcc and make are required
# then: cpan Cpanel::JSON::XS
use Cpanel::JSON::XS qw(encode_json decode_json);
use IO::Handle;

my $Verbose = 1;
if ( $Verbose ) {
	use Data::Dumper;
	$Carp::Verbose = 1;
}
use auxmod::UploadVars qw (
$prefix
$sparql_prefixes
);

use Exporter;
# TODO clean up exports
our @ISA = qw(Exporter);
our @EXPORT = qw(
open_read
open_write
__date
benchmark
char_http
print_counts
read_map
extract_map
extract_hash
filter_tsv_by_map
filter_updat
write_ttl_header
write_ttl_preambule
write_ttl_properties
add_chains
add_priority_over_isa
add_subsumption
add_superproperties
add_transitivity
add_transitivity_over
add_triples 
clear_graph
copy_triples 
get_graphs
get_base_file_names
);

############################ Sufficient for BGW ################################################

sub open_read {
	my ($file) = @_;
	open my $FH, '<', $file or croak "File: $file cannot be opened!";
	return $FH;
}

sub open_write {
	my ( $file, $mode ) = @_;
	$mode ||= '>';
	my $FH;
	open $FH, $mode, $file; # TODO test it
	
# 	$mode eq '-a' ?
# 	open $FH, '>>', $file :
# 	open $FH, '>', $file;
	croak "File: $file cannot be opened!" unless $FH;
	return $FH;
}

sub __date {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	 # e.g. 2008:05:11 12:52
	my $result = sprintf "%4d:%02d:%02d %02d:%02d", $year+1900,$mon+1,$mday,$hour,$min;
}

sub benchmark {
	my ( 
	$start_time, 
	$message, 
	$date, # boolean
	) = @_;
	my $elapsed_time = (time - $start_time)/60;
	$message = "$message in ";
	$date ? 
	print $message, sprintf("%.2f", $elapsed_time), " min ", __date(), "\n" : 
	print $message, sprintf("%.2f", $elapsed_time), " min\n";
}

sub print_counts {
	# counts the number of entries at the 3rd level in a nested hash
	my ( $data, $level ) = @_;
	$level ||= 3;
	if ( $level == 3 ) {
		foreach my $primk ( sort keys %{$data} ) {
			map { my $count = keys %{$data->{$primk}{$_}}; 
			print "$primk:$_ $count\n"; } sort keys %{$data->{$primk}};
		}
	}
	elsif ( $level == 2 ) {
		foreach my $primk ( sort keys %{$data} ) {
			my $count = keys %{$data->{$primk}}; 
			print "$primk: $count\n";
		}
	}
}

sub extract_hash {
	# used only in download.pl
	my ( 
	$in_file, 
	$key_ind, # indexing starts at '0'
	$val_ind # optional
	) = @_;
	my $FH = open_read ( $in_file );
	my %hash;
	while (<$FH>) {
		next if substr ( $_, 0, 1) eq "\n";
		next if substr ( $_, 0, 1) eq "#";
		next if substr ( $_, 0, 1) eq "!";
		chomp;
		my ( @fields ) = split /\t/;
		my $key = $fields[$key_ind];
		next unless $key;
		if ( ! $val_ind ) {
			$hash{$key}++; # counting the number of lines with $key
		}
		else {
			my $val = $fields[$val_ind];
			$hash{$key}{$val}++ if $val;
		}
	}
	close $FH;
	my @keys = keys %hash;
	return \%hash; # should be this way, no conditionals
}

sub extract_map {
## Attn: in case of multiple values uses just the first occurence
	my ( 
	$in_file, 
	$key_ind, # indexing starts at '0'
	$val_ind # optional
	) = @_;
	my $FH = open_read ( $in_file );
	my %map;
	while (<$FH>) {
		next if substr ( $_, 0, 1) eq "\n";
		next if substr ( $_, 0, 1) eq "#";
		next if substr ( $_, 0, 1) eq "!";
		chomp;
		my ( @fields ) = split /\t/;
		my $key = $fields[$key_ind];
		next unless $key;
		if ( ! $val_ind ) {
			$map{$key}++; # counting the number of lines with $key
		}
		else {
			my $val = $fields[$val_ind];
			if ($map{$key}) {
				carp "Already exits: '$key-$map{$key}', ignored: '$key-$val'";
				next; # only the first occurence is retained
			}
			$map{$key} = $val if $val;
		}
	}
	close $FH;
	my @keys = keys %map;
	return \%map; # should be this way, no conditionals
}

sub filter_tsv_by_map {
# TODO consider outputing to STDOUT or accepting multiple in files
	my ( 
	$in_file,
	$out_file, 
	$map, 
	$key_ind, # indexing starts at '0'
	) = @_;
	my %keys;
# 	open my $IN, '<', $in_file or croak "Cannot open file '$in_file': $!";
	my $IN = open_read ( $in_file );
# 	open my $OUT, '>', $out_file or croak "Cannot open file '$out_file': $!";
	my $OUT = open_write( $out_file );
	while (<$IN>) {
		next if substr ( $_, 0, 1) eq "\n";
		next if substr ( $_, 0, 1) eq "#";
		chomp;
		my ( @fields ) = split /\t/;
		next unless my $key = $fields[$key_ind];
		next unless $map->{$key};
		$keys{$key}++;
		print $OUT "$_\n";
	}
	close $IN;
	close $OUT;
	return \%keys; # should be this way, no conditionals
}

sub read_map {
## Attn: only the first two fields of the table are  used !
	my ( $map_file, $mode ) = @_;
	$mode ||= 0; # not needed
# 	open my $FH, '<', $map_file or croak "Cannot open file '$map_file': $!";
	my $FH = open_read ( $map_file );
	my %map;
	while (<$FH>) {
		next if substr ( $_, 0, 1) eq "\n";
		next if substr ( $_, 0, 1) eq "#";
		chomp;
		my ( $left, $right ) = split /\t/;
		if ( $mode == 1) {
			push @{$map{$right}}, $left;
		}
		elsif ( $mode == 2 ) {
			push @{$map{$left}}, $right;
		}
		else {
			$map{$left} = $right;
		}
	}
	close $FH;
	return \%map;
}

sub filter_updat {
	my (
	$infiles, # ref to an array of data file full paths
	$out_file_path, # UniProt .dat file
# 	$taxon, # NCBI_TaxID
	$rex, # should capture a single value
	$map, # ref to a hash for filtering
	) = @_;
# 	open my $DAT, '>', $out_file_path or croak "File $out_file_path cannot be opened: $!";
	my $DAT = open_write( $out_file_path );
	my %seen;
	my $rex_frg = qr/^DE\s{3}Flags:\s.*?Fragment.*?$/xmso; # should stay here
	foreach my $in_file ( @{$infiles} ) {
		chomp $in_file;
# 		open my $IN, '<', $in_file or croak "File: $in_file cannot be opened";
		my $IN = open_read ( $in_file );
		local $/ = "\n//\n";
		# TODO test the new regexes
# 		my $rex_ac = qr/^AC\s{3}(\w+)/xmso; # matches only the first AC
		while (<$IN>) {
			my $entry = $_;
			my ( $hit ) = $entry =~ $rex;
			next unless $hit;
			if ( $map ) {
				next unless $map->{$hit};
			}
			next if $seen{$hit}; # a second entry with the same AC (happens)
			$seen{$hit}++;
			print $DAT "$entry";
		}		
	}
	close $DAT;
	my $keys = keys %seen;
	$keys ? return \%seen : carp "filter_updat has nothing to return";
}

sub write_ttl_preambule {
	my (
	$uris,
	) = @_;
	
	my $buffer;
	map { $buffer .= "\@prefix $_: <$uris->{$_}> .\n"} sort keys %{$uris};
	$buffer.= "\n";
	return $buffer;
}


sub write_ttl_header {
	my ( $header, ) = @_;
	my $buffer = <<BFR;

###############################################################################
##
##	$header
##
###############################################################################

BFR
	return $buffer;
}

sub write_ttl_properties {
	# NOTE; namespaces absent in %uris converted to 'obo' ! Special case - SIO
	my (
	$uris,
	$props, # a ref to SharedVars::%rlstp
	$keys, # ref to an array of keys to be used in 
	) = @_;
	
	my $buffer = '';
	foreach ( @{$keys} ) {
		my ( $NS, $id, $label ) = @{ $props->{$_} };
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
		$buffer .= "### $uri$rdfid ###\n\n";
		$buffer .= "$ns:$rdfid rdfs:subPropertyOf owl:ObjectProperty ;\n";
		$buffer .= "\tskos:prefLabel \"$label\" .\n\n";
	}
	return $buffer;
}

sub char_http {
# TODO sort out this mess
	## can be escaped with a '\'in the local names in RDF:
	## ~.-!$&'()*+,;=/?#@%_
	if ($_[0]) {
# 		$_[0] =~ s/:/ - /g;
		$_[0] =~ s/;/ - /g;
		$_[0] =~ s/</-lt-/g;
		$_[0] =~ s/</(/g;
		$_[0] =~ s/=/-eq-/g;
		$_[0] =~ s/>/)/g;
		$_[0] =~ s/\?/-qm-/g;
		$_[0] =~ s/&/-and-/g;
		
	#number sign                    #     23   &#035; --> #   &num;      --> &num;
	#dollar sign                    $     24   &#036; --> $   &dollar;   --> &dollar;
	#percent sign                   %     25   &#037; --> %   &percnt;   --> &percnt;
	
		$_[0] =~ s/\\+/\\\\/;
		$_[0] =~ tr/"/'/;
	
		return $_[0];
	} else {
		return "";
	}
}

################################ SQL ##########################################

# arguments:
# 1. graph name without prefix to add the closures to
# 2. source graph name (e.g. 'gene_ontology_edit' for goa, though can be the same as the previous one )
# 3. prefixes (string, prefixes \n separated)
# 5. inderect file handle for writing (optional unless $SQL)
# 6. DB handle (optional if $SQL)
sub add_chains {
# Note: only for owl files, not used in any download/obo/*.obo
	my (
		$graph_name,
		$sparql_prefixes,
		$SQL,
		$dbh,
	) = @_;
$SQL = *STDOUT unless $SQL;
my $query = <<HD;
DEFINE sql:log-enable 2
$sparql_prefixes
INSERT INTO GRAPH <$graph_name> {
  ?class1 ?property ?class3 . 
}
WHERE {
  GRAPH <$graph_name> {
    ?property owl:propertyChainAxiom ?collection1 . 
    ?collection1 rdf:first ?property1 . 
    ?collection1 rdf:rest ?collection2 . 		
    ?collection2 rdf:first ?property2 . 
    ?class1 ?property1 ?class2 .
    ?class2 ?property2 ?class3 .
  }
}
HD

	print $SQL "sparql\n$query;\n";
	if ( $dbh ) {
		my $command = "sparql\n$query";
		my $sth = $dbh->prepare ( $command );
		$sth->execute ();
	}
}

# arguments:
# 1. graph name without prefix to add the closures to
# 2. source graph name (can be the same as the previous, e.g. 'gene_ontology_edit' for goa)
# 3. prefixes (string, prefixes \n separated)
# 4. number of iterations
# 5. subsumtion relation (ssb:is_ | rdfs:subClassOf)
# 6. inderect file handle for writing
# 7. DB handle (optional)
sub add_priority_over_isa {
	my (
		$graph_name,
		$sparql_prefixes,
		$SQL,
		$dbh,
	) = @_;
	$SQL = *STDOUT unless $SQL;
	my $query = <<HD;
DEFINE sql:log-enable 2
$sparql_prefixes
INSERT INTO GRAPH <$graph_name> {
  ?class1 ?property ?class3 . 
}
WHERE {
  GRAPH <$graph_name> {
    ?property a owl:ObjectProperty .
    {
    ?class1 rdfs:subClassOf ?class2 .
    ?class2 ?property ?class3 .
    } UNION {
    ?class1 ?property ?class2 .
    ?class2 rdfs:subClassOf ?class3 .
    }
  }
}
HD

	print $SQL "sparql\n$query;\n";
	if ( $dbh ) {
		my $command = "sparql\n$query";
		my $sth = $dbh->prepare ( $command );
		$sth->execute ();
	}
}

# arguments:
# 1. graph name without namespace to add the closures to
# 2. prefixes (string, prefixes \n separated)
# 3. the number of iterations
# 4. indirect file handle
# 5. DB handle (optional)
sub add_subsumption {
	# TODO to be tested
	my (
		$graph_name,
		$sparql_prefixes,
		$SQL,
		$dbh
	) = @_;
	$SQL = *STDOUT unless $SQL;
	my $query = <<HD;
DEFINE sql:log-enable 2
$sparql_prefixes
INSERT INTO GRAPH <$graph_name> {
  ?class1 rdfs:subClassOf ?class2. 
}
WHERE {
  GRAPH <$graph_name> {
    ?class1 rdfs:subClassOf+ ?class2.
    ?class1 rdfs:label ?name1.
    ?class2 rdfs:label ?name2.
  }
}
HD

	print $SQL "sparql\n$query;\n";
	if ( $dbh ) {
		my $command = "sparql\n$query";
		my $sth = $dbh->prepare ( $command );
		$sth->execute ();
	}
}

# arguments:
# 1. graph name without namespace to add closures to
# 2. prefixes (string, prefixes \n separated)
# 3. inderect file handle
# 4. DB handle
sub add_superproperties {
# TODO quantification: ?class1 ?rel_id+ ?class2
	my (
		$graph_name,
		$rel_id,
		$super_rel_id,
		$sparql_prefixes,
		$SQL,
		$dbh
	) = @_;
	$SQL = *STDOUT unless $SQL;
	my $query = <<HEREDOC;
DEFINE sql:log-enable 2
$sparql_prefixes
INSERT INTO GRAPH <$graph_name> {
  ?class1 $super_rel_id ?class2 .
}
WHERE {
  GRAPH <$graph_name> {
#     ?rel_id rdfs:subPropertyOf ?super_rel_id . # TODO implement
    ?class1 $rel_id ?class2 .
  }
}
HEREDOC

	print $SQL "sparql\n$query;\n";
	if ( $dbh ) {
		my $command = "sparql\n$query";
		my $sth = $dbh->prepare ( $command );
		$sth->execute ();
	}
}

# arguments:
# 1. graph name without namespace to add the closures to
# 2. prefixes (string, prefixes \n separated)
# 3. the number of iterations
# 4. indirect file handle
# 5. DB handle (optional)
sub add_transitivity {
	# TODO list of transitive properties as an arguments
	# TODO eliminate looping ?
	my (
		$graph_name,
		$rel_id, # e.g. obo:RO_000050
		$sparql_prefixes,
		$SQL,
		$dbh
	) = @_;
	$SQL = *STDOUT unless $SQL;
	my $query = <<HEREDOC;
DEFINE sql:log-enable 2
$sparql_prefixes
INSERT INTO GRAPH <$graph_name> {
  ?class1 $rel_id ?class2 .	
}
WHERE {
  GRAPH <$graph_name> {
    ?class1 $rel_id+ ?class2 .	
    # 'transitive start not given' without the lines below
    ?class1 rdfs:label ?name1 .
    ?class2 rdfs:label ?name2 .
  }
}
HEREDOC

	print $SQL "sparql\n$query;\n";
	if ( $dbh ) {
		my $command = "sparql\n$query";
		my $sth = $dbh->prepare ( $command );
		$sth->execute ();
	}
}

sub add_transitivity_over {
	my (
		$graph_name,
		$rel1_id, # e.g. 'obo:RO_0002211'
		$rel2_id, # e.g. 'obo:BFO_0000050'
		$sparql_prefixes,
		$SQL,
		$dbh,
	) = @_;
	$SQL = *STDOUT unless $SQL;
	my $query = <<HD;
DEFINE sql:log-enable 2
$sparql_prefixes
INSERT INTO GRAPH <$graph_name> {
  ?class1 $rel1_id ?class3 . 
}
WHERE {
  GRAPH <$graph_name> {
    ?class1 $rel1_id ?class2 .
    ?class2 $rel2_id ?class3 .
    ?class1 rdfs:label ?name1 .
    ?class2 rdfs:label ?name2 .
    ?class3 rdfs:label ?name3 .

  }
}
HD

	print $SQL "sparql\n$query;\n";
	if ( $dbh ) {
		my $command = "sparql\n$query";
		my $sth = $dbh->prepare ( $command );
		$sth->execute ();
	}
}

# adds triples from .owl, *.rdf and *.ttl files to the graphs
# works both with rdf xml and turtle
# args:
# 1. source file name, fully qualified
# 2. default URI e.g. 'http://www.semantic-systems-biology.org/SSB' or even ''
# 3. graph URI
# 4. indirect file handle
# 5. DB handle
sub add_triples {
	# TODO update the calls in all functions calling this one !!!
	# Note: $prefix must match the base URI in the RDF file ???
	my ( 
	$source_file,  
	$prefix, # default base URI for resolving relative URIs
	$graph_uri, 
	$SQL, 
	$dbh 
	) = @_;
	if ( ! -e $source_file ) {
		carp "File '$source_file' does not exist: $!";
		return;
	};
	$SQL = *STDOUT unless $SQL;
	my ( $load_cmd, $command );
	if ( $source_file =~ /\A\S+\.rdf\z/xms or $source_file =~ /\A\S+\.owl\z/xms ) {
		$load_cmd = "DB.DBA.RDF_LOAD_RDFXML_MT(file_to_string_output('%s'), '%s', '%s' )";
	}
	elsif ( $source_file =~ /\A\S+\.ttl\z/xms ){
		$load_cmd = "DB.DBA.TTLP_MT(file_to_string_output('%s'),'%s','%s' )";
	}
	else {
		carp "illegitimate file type: $source_file";
		return;
	}
	
	$command = sprintf ( $load_cmd, $source_file, $prefix, $graph_uri );
	#~ $load_cmd = "DB.DBA.RDF_LOAD_RDFXML_MT(file_to_string_output('%s'), '%s', '%s', %d, %d )";
	#~ $command = sprintf ( $load_cmd, $source_file, $prefix, $graph_uri, 2, 24  );

	
	print $SQL "$command;\n";

	if ( $dbh ) {
		my $sth = $dbh->prepare ( $command );
		$sth->execute ();
	}
}

# args:
# 1. graph name, fully qualified
# 2. inderect filehandle
# 3. DB handle, optional
sub clear_graph {
	my ( $graph, $SQL, $dbh ) = @_;
	$SQL = *STDOUT unless $SQL;
	my $command = sprintf ( "sparql clear graph '$graph'" );
	print $SQL "$command;\n";
	if ( $dbh ) {
		my $sth = $dbh->prepare ( $command );
		$sth->execute ();
	}
}

# copies triples from one specified graph to  a list of graphs
# arguments:
# 1. target graph name without namespace
# 2. source graph name without namespace
# 3. prefixes (string, prefixes \n separated)
# 4. inderect file handle
# 5. DB handle
sub copy_triples {
	my ( $target_graph_name, $source_graph_name, $sparql_prefixes, $SQL, $dbh ) = @_;
	$SQL = *STDOUT unless $SQL;
	my $command = "sparql\nDEFINE sql:log-enable 2\n";
	$command .= $sparql_prefixes;
	$command .= "INSERT INTO GRAPH <$target_graph_name> {\n";
	$command .= "  ?s ?p ?o.\n";
	$command .= "}\n";
	$command .= "WHERE {\n";
	$command .= "  GRAPH <$source_graph_name> {\n";
	$command .= "    ?s ?p ?o.\n";
	$command .= "  }\n";
	$command .= "}\n";
	print $SQL "$command;\n";
	if ( $dbh ) {
		my $sth = $dbh->prepare ( $command );
		$sth->execute ();
	}
}

# generates an arrary of graph names for all the *.owl, *.rdf and *.ttl files in a given directory
# arguments:  full dir path
sub get_graphs {
	my ( $dir_path ) = @_;
	opendir ( DIR, "$dir_path" ) || croak "Cannot open the directory $dir_path: $!";
	my @dir_contents = readdir ( DIR );
	closedir ( DIR );
	my @graphs;
	foreach my $file_name (@dir_contents) {
		if ( $file_name =~ /\A(\S+)\.rdf\z/xms or $file_name =~ /\A(\S+)\.owl\z/xms or $file_name =~ /^(\S+)\.ttl$/xms) {
			push @graphs, $1;
		}
	}
	return @graphs;
}

# returns an arrary of file names from a given directory and of a particular type (no path, no extention)
sub get_base_file_names {
	# TODO move it to SharedSubs
	# TODO extention of any length
	my ( 
	$dir, # full path
	$ext # 3 char extention
	) = @_;
	my @names = map { my @splits = split /\//, $_; $_ = pop @splits; }
					 map { substr $_, 0, -5; } # removing '.$ext\n'
					 `ls $dir/*.$ext`;
	return @names;
}

1;
