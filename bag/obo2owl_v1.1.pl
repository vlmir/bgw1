#!/usr/bin/perl -w

use strict;
use Tie::File;

sub usage {
	print "$0 <obo_file> <owl_file>\n";
	print "obo_file: the name of the obo file of the ontology\n";
	print "owl_file: the name of the owl file to store the ontology\n";
	exit -1;
}

my $oboFile = shift or usage();
my $owlFile = shift or usage();

open outFile, ">log.txt";
print outFile "Could not convert the following lines --->\n";

print "Do you want the OWL file to contain oboInOwl mapping [y/n]\n";
my $choice = <STDIN>;
chomp($choice);


#~ my $ms;
#~ BEGIN {
  #~ $ms = Win32::GetTickCount();
#~ }

my @temp;
tie @temp, 'Tie::File', "$oboFile" or die "Unable to tie file $oboFile.";
#print "Finished reading " . scalar @temp . " lines.\n";

#first create the header
my $namespace;
my $nameFull;
foreach (@temp) {
	if ($_ =~ m/default-namespace: /) {
		my @name = split(/ /, $_);
		$namespace = $name[1];
		last;
	}
}
#print "The namespace is: $namespace\n";
$nameFull = "http://www.example.org/" . $namespace;

open myFile, ">$owlFile" or die "Unable to open file $owlFile\n";
print myFile "<?xml version=\"1.0\"?>\n";
print myFile "<rdf:RDF xmlns:mi=\"$nameFull#\"\n";
print myFile "     xml:base=\"$nameFull\"\n";
print myFile "     xmlns:rdfs=\"http://www.w3.org/2000/01/rdf-schema#\"\n";
print myFile "     xmlns:xsd=\"http://www.w3.org/2001/XMLSchema#\"\n";
print myFile "     xmlns:owl=\"http://www.w3.org/2002/07/owl#\"\n";
print myFile "     xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"\n";
if ($choice eq 'y') {
print myFile "     xmlns:obo=\"http://purl.obolibrary.org/obo/\"\n";
}
print myFile "     xmlns:oboInOwl=\"http://www.geneontology.org/formats/oboInOwl#\">\n";
print myFile "    <owl:Ontology rdf:about=\"$nameFull\"/>\n\n";


print myFile "    <owl:AnnotationProperty rdf:about=\"http://www.geneontology.org/formats/oboInOwl#hasAlternativeId\">\n";
print myFile "        <rdfs:label rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">has_alternative_id</rdfs:label>\n";
print myFile "    </owl:AnnotationProperty>\n";
print myFile "    <owl:AnnotationProperty rdf:about=\"http://www.geneontology.org/formats/oboInOwl#hasExactSynonym\">\n";
print myFile "        <rdfs:label rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">has_exact_synonym</rdfs:label>\n";
print myFile "    </owl:AnnotationProperty>\n";
print myFile "    <owl:AnnotationProperty rdf:about=\"http://www.geneontology.org/formats/oboInOwl#hasBroadSynonym\">\n";
print myFile "        <rdfs:label rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">has_broad_synonym</rdfs:label>\n";
print myFile "    </owl:AnnotationProperty>\n";
print myFile "    <owl:AnnotationProperty rdf:about=\"http://www.geneontology.org/formats/oboInOwl#hasNarrowSynonym\">\n";
print myFile "        <rdfs:label rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">has_narrow_synonym</rdfs:label>\n";
print myFile "    </owl:AnnotationProperty>\n";
print myFile "    <owl:AnnotationProperty rdf:about=\"http://www.geneontology.org/formats/oboInOwl#hasRelatedSynonym\">\n";
print myFile "        <rdfs:label rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">has_related_synonym</rdfs:label>\n";
print myFile "    </owl:AnnotationProperty>\n";
print myFile "    <owl:AnnotationProperty rdf:about=\"http://www.geneontology.org/formats/oboInOwl#hasOBONamespace\">\n";
print myFile "        <rdfs:label rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">has_obo_namespace</rdfs:label>\n";
print myFile "    </owl:AnnotationProperty>\n";
print myFile "    <owl:AnnotationProperty rdf:about=\"http://www.geneontology.org/formats/oboInOwl#creation_date\"/>\n";
print myFile "    <owl:AnnotationProperty rdf:about=\"http://www.geneontology.org/formats/oboInOwl#created_by\"/>\n";
print myFile "    <owl:AnnotationProperty rdf:about=\"http://www.geneontology.org/formats/oboInOwl#hasDbXref\">\n";
print myFile "        <rdfs:label rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">database_cross_reference</rdfs:label>\n";
print myFile "    </owl:AnnotationProperty>\n";
print myFile "    <owl:AnnotationProperty rdf:about=\"$nameFull#hasDefXref\">\n";
print myFile "        <rdfs:label rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">definition_cross_reference</rdfs:label>\n";
print myFile "    </owl:AnnotationProperty>\n";
if ($choice eq 'y') {
	print myFile "    <owl:AnnotationProperty rdf:about=\"http://purl.obolibrary.org/obo/IAO_0000115\">\n";
	print myFile "        <rdfs:label rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">definition</rdfs:label>\n";
	print myFile "    </owl:AnnotationProperty>\n";
}


my $check;
my $iid='';
foreach (my $i=0; $i< scalar @temp; $i++) {
	if ($temp[$i] eq '') {
		print myFile "\n";
	}
	elsif ($temp[$i] =~ m/\[Term\]/) {
		print myFile "  <owl:Class rdf:ID=\"";

		foreach (my $j=$i+1; $j < scalar @temp; $j++) {
			if (($temp[$j] =~ m/^id: /) and ($temp[$j] !~ m/^alt_id:/)) {
				my @data = split(/ /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				print myFile "$data[1]\">\n";
				next;
			}
			elsif ($temp[$j] =~ m/^name:/) {
				my @data = split(/name: /, $temp[$j]);
				$data[1] =~ s/&/ and /g;
				$data[1] =~ s/</ /g;
				$data[1] =~ s/>/ /g;
				print myFile "    <rdfs:label rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</rdfs:label>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^def:/) {
				my @data = split(/"/, $temp[$j]);
				my $def=$data[1];
				$def =~ s/&/ and /g;
				$def =~ s/</ less than /g;
				$def =~ s/>/ greater than /g;
				my $xr=$data[2];
				$xr =~ s/:/_/g;
				$xr =~ s/&/_/g;
				if ($choice eq 'y'){
					print myFile "    <obo:IAO_0000115 rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$def</obo:IAO_0000115>\n";
					print myFile "    <mi:hasDefXref>$xr</mi:hasDefXref>\n";
				}
				else {
					print myFile "    <rdfs:isDefinedBy rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$def</rdfs:isDefinedBy>\n";
					print myFile "    <mi:hasDefXref>$xr</mi:hasDefXref>\n";
				}
				next;
			}
			elsif ($temp[$j] =~ m/^relationship:/) {
				my @data = split(/ /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				$data[2] =~ s/:/_/g;
				print myFile "    <rdfs:subClassOf>\n";
				print myFile "      <owl:Restriction>\n";
				print myFile "        <owl:onProperty>\n";
				print myFile "          <owl:ObjectProperty rdf:ID=\"$data[1]\"/>\n";
				print myFile "        </owl:onProperty>\n";
				print myFile "        <owl:someValuesFrom>\n";
				print myFile "          <owl:Class rdf:ID=\"$data[2]\"/>\n";
				print myFile "        </owl:someValuesFrom>\n";
				print myFile "      </owl:Restriction>\n";
				print myFile "    </rdfs:subClassOf>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^comment:/) {
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/&/and/g;
				$data[1] =~ s/</ /g;
				$data[1] =~ s/</ /g;
				print myFile "    <rdfs:comment>$temp[1]</rdfs:comment>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^is_a:/) {
				my @data = split(/: /, $temp[$j]);
				my @d2 = split(/ !/, $data[1]);
				$d2[0] =~ s/:/_/g;
				print myFile "    <rdfs:subClassOf rdf:resource=\"#$d2[0]\"/>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^intersection_of:/) {
				my $k = $j++;
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				print myFile "    <owl:intersectionOf rdf:parseType=\"Collection\">\n";
				print myFile "      <owl:Class rdf:ID=\"$data[1]\"/>\n";
				my @d2 = split(/ /, $temp[$k]);
				my $prop = $d2[1];
				$prop =~ s/:/_/g;
				my $range = $d2[2];
				$range =~ s/:/_/g;
				print myFile "      <owl:Restriction>\n";
				print myFile "        <owl:onProperty>\n";
				print myFile "          <owl:ObjectProperty rdf:ID=\"$prop\"/>\n";
				print myFile "        </owl:onProperty>\n";
				print myFile "        <owl:someValuesFrom>\n";
				print myFile "          <owl:Class rdf:ID=\"$range\"/>\n";
				print myFile "        </owl:someValuesFrom>\n";
				print myFile "      </owl:Restriction>\n";
				print myFile "      </owl:intersectionOf>\n";
				$j++;
				next;
			}
			elsif ($temp[$j] =~ m/^disjoint_from:/) {
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				print myFile "    <owl:disjointWith>\n";
				print myFile "      <owl:Class rdf:ID=\"$data[1]\"/>\n";
				print myFile "    </owl:disjointWith>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^alt_id:/) {
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				$data[1] =~ s/&/and/g;
				$data[1] =~ s/</ /g;
				$data[1] =~ s/</ /g;
					print myFile "    <oboInOwl:hasAlternativeId rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:hasAlternativeId>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^namespace:/) {
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				$data[1] =~ s/&/and/g;
				$data[1] =~ s/</ /g;
				$data[1] =~ s/</ /g;
				print myFile "    <oboInOwl:hasOBONamespace rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:hasOBONamespace>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^created_by:/) {
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				$data[1] =~ s/&/and/g;
				$data[1] =~ s/</ /g;
				$data[1] =~ s/</ /g;
				print myFile "    <oboInOwl:created_by rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:created_by>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^creation_date:/) {
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				$data[1] =~ s/&/and/g;
				$data[1] =~ s/</ /g;
				$data[1] =~ s/</ /g;
				print myFile "    <oboInOwl:creation_date rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:creation_date>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^xref:/) {
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				$data[1] =~ s/&/ and /g;
				$data[1] =~ s/<//g;
				$data[1] =~ s/>//g;
				$data[1] =~ s/\//-/g;
				$data[1] =~ s/<br>//g;
				print myFile "    <oboInOwl:hasDbXref rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:hasDbXref>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^is_obsolete:/) {
				print myFile "    <owl:deprecated rdf:datatype=\"http://www.w3.org/2001/XMLSchema#boolean\">true</owl:deprecated>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^synonym:/) {
			    if ($temp[$j] =~ m/EXACT /) {
				   my @data = split(/"/, $temp[$j]);
				   $data[1] =~ s/:/_/g;
				   $data[1] =~ s/&/and/g;
				   $data[1] =~ s/</ /g;
				   $data[1] =~ s/</ /g;
				   print myFile "    <oboInOwl:hasExactSynonym rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:hasExactSynonym>\n";
				   next;
				}
				if ($temp[$j] =~ m/BROAD /) {
				   my @data = split(/"/, $temp[$j]);
				   $data[1] =~ s/:/_/g;
				   $data[1] =~ s/&/and/g;
				   $data[1] =~ s/</ /g;
				   $data[1] =~ s/</ /g;
				   print myFile "    <oboInOwl:hasBroadSynonym rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:hasBroadSynonym>\n";
				   next;
				}
				if ($temp[$j] =~ m/NARROW /) {
				   my @data = split(/"/, $temp[$j]);
				   $data[1] =~ s/:/_/g;
				   $data[1] =~ s/&/and/g;
				   $data[1] =~ s/</ /g;
				   $data[1] =~ s/</ /g;
				   print myFile "    <oboInOwl:hasNarrowSynonym rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:hasNarrowSynonym>\n";
				   next;
				}
				if ($temp[$j] =~ m/RELATED /) {
				   my @data = split(/"/, $temp[$j]);
				   $data[1] =~ s/:/_/g;
				   $data[1] =~ s/</_/g;
				   $data[1] =~ s/>/_/g;
				   $data[1] =~ s/&/and/g;
				   print myFile "    <oboInOwl:hasRelatedSynonym rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:hasRelatedSynonym>\n";
				   next;
				}

			}
			elsif ($temp[$j] =~ /^\s*$/) {
				print myFile "  </owl:Class>\n\n";
				last;
			}
			else {
			    print outFile "Line $i: $temp[$j]\n";
				next;
				#$i = $j;
			}
		}

	}
	elsif ($temp[$i] =~ m/\[Typedef\]/) {
		print myFile "  <owl:ObjectProperty rdf:ID=\"";
		foreach (my $j=$i+1; $j < scalar @temp; $j++) {
			if (($temp[$j] =~ m/^id:/) and ($temp[$j] !~ m/^alt_id:/)) {
				my @data = split(/ /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				print myFile "$data[1]\">\n";
				next;
			}
			elsif ($temp[$j] =~ m/^name:/) {
				my @data = split(/name: /, $temp[$j]);
				$data[1] =~ s/&/ and /g;
				$data[1] =~ s/</ /g;
				$data[1] =~ s/>/ /g;
				print myFile "    <rdfs:label rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</rdfs:label>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^def:/) {
				my @data = split(/\"/, $temp[$j]);
				my $def=$data[1];
				$def =~ s/&/ and /g;
				$def =~ s/</ less than /g;
				$def =~ s/>/ greater than /g;
				if ($choice eq 'y'){
					print myFile "    <obo:IAO_0000115 rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$def</obo:IAO_0000115>\n";
				}
				else {
					print myFile "    <rdfs:isDefinedBy rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$def</rdfs:isDefinedBy>\n";
				}
				next;
			}
			elsif ($temp[$j] =~ m/^comment:/) {
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/&/and/g;
				$data[1] =~ s/</ /g;
				$data[1] =~ s/</ /g;
				print myFile "    <rdfs:comment>$temp[1]</rdfs:comment>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^is_a:/) {
				my @data = split(/: /, $temp[$j]);
				my @d2 = split(/ !/, $data[1]);
				$d2[0] =~ s/:/_/g;
				print myFile "    <rdfs:subPropertyOf rdf:resource=\"#$d2[0]\"/>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^disjoint_from:/) {
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				print myFile "    <owl:disjointWith>\n";
				print myFile "      <owl:ObjectProperty rdf:ID=\"$data[1]\"/>\n";
				print myFile "    </owl:disjointWith>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^alt_id:/) {
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				$data[1] =~ s/&/and/g;
				$data[1] =~ s/</ /g;
				$data[1] =~ s/</ /g;
				print myFile "    <oboInOwl:hasAlternativeId rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:hasAlternativeId>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^namespace:/) {
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				$data[1] =~ s/&/and/g;
				$data[1] =~ s/</ /g;
				$data[1] =~ s/</ /g;
				print myFile "    <oboInOwl:hasOBONamespace rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:hasOBONamespace>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^creation_date:/) {
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				$data[1] =~ s/&/and/g;
				$data[1] =~ s/</ /g;
				$data[1] =~ s/</ /g;
				print myFile "    <oboInOwl:creation_date rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:creation_date>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^created_by:/) {
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				$data[1] =~ s/&/and/g;
				$data[1] =~ s/</ /g;
				$data[1] =~ s/</ /g;
				print myFile "    <oboInOwl:created_by rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:created_by>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^xref:/) {
				my @data = split(/: /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				$data[1] =~ s/&/ and /g;
				$data[1] =~ s/&/and/g;
				$data[1] =~ s/</ /g;
				$data[1] =~ s/</ /g;
				print myFile "    <oboInOwl:hasDbXref rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:hasDbXref>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^inverse_of:/) {
				my @data = split(/ /, $temp[$j]);
				$data[1] =~ s/:/_/g;
				print myFile "    <owl:inverseOf rdf:ID=\"$data[1]\"/>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^is_transitive:/) {
				print myFile "    <rdf:type rdf:resource=\"http://www.w3.org/2002/07/owl#TransitiveProperty\"/>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^is_symmetric:/) {
				print myFile "    <rdf:type rdf:resource=\"http://www.w3.org/2002/07/owl#SymmetricProperty\"/>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^is_obsolete:/) {
				print myFile "    <owl:deprecated rdf:datatype=\"http://www.w3.org/2001/XMLSchema#boolean\">true</owl:deprecated>\n";
				next;
			}
			elsif ($temp[$j] =~ m/^synonym:/) {
			    if ($temp[$j] =~ m/EXACT /) {
				   my @data = split(/"/, $temp[$j]);
				   $data[1] =~ s/:/_/g;
				   $data[1] =~ s/&/and/g;
				   $data[1] =~ s/</ /g;
				   $data[1] =~ s/</ /g;
				   print myFile "    <oboInOwl:hasExactSynonym rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:hasExactSynonym>\n";
				   next;
				}
				if ($temp[$j] =~ m/BROAD /) {
				   my @data = split(/"/, $temp[$j]);
				   $data[1] =~ s/:/_/g;
				   $data[1] =~ s/&/and/g;
				   $data[1] =~ s/</ /g;
				   $data[1] =~ s/</ /g;
				   print myFile "    <oboInOwl:hasBroadSynonym rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:hasBroadSynonym>\n";
				   next;
				}
				if ($temp[$j] =~ m/NARROW /) {
				   my @data = split(/"/, $temp[$j]);
				   $data[1] =~ s/:/_/g;
				   $data[1] =~ s/&/and/g;
				   $data[1] =~ s/</ /g;
				   $data[1] =~ s/</ /g;
				   print myFile "    <oboInOwl:hasNarrowSynonym rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:hasNarrowSynonym>\n";
				   next;
				}
				if ($temp[$j] =~ m/RELATED /) {
				   my @data = split(/"/, $temp[$j]);
				   $data[1] =~ s/:/_/g;
				   $data[1] =~ s/</_/g;
				   $data[1] =~ s/>/_/g;
				   $data[1] =~ s/&/and/g;
				   $data[1] =~ s/</ /g;
				   $data[1] =~ s/</ /g;
				   print myFile "    <oboInOwl:hasRelatedSynonym rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">$data[1]</oboInOwl:hasRelatedSynonym>\n";
				   next;
				}

			}
			elsif ($temp[$j] =~ /^\s*$/) {
				print myFile "  </owl:ObjectProperty>\n\n";
				last;
			}
			else {
			    print outFile "Line $i: $temp[$j]\n";
				next;
				#$i = $j;
			}
		}

	}
}

print myFile "</rdf:RDF>\n";
print "Done!\n";


























