#!/usr/bin/perl -w

use strict;
use Tie::File;

sub usage {
	print "$0 <owl_file> <obo_file>\n";
	print "owl_file: the name of the owl file of the ontology\n";
	print "obo_file: the name of the obo file to store the ontology\n";
	exit -1;
}

my $ms;
BEGIN {
  $ms = Win32::GetTickCount();
}

print "Do you want the script to automatically generate names for nameless terms? [y/n]\n";
my $choice = <STDIN>;
chomp($choice);

open outFile, ">log.txt";
print outFile "Could not convert the following lines --->\n";

my $owlFile = shift or usage();
my $oboFile = shift or usage();

my @tempt;
tie @tempt, 'Tie::File', "$owlFile" or die "Unable to tie file $owlFile.";
print "Finished reading " . scalar @tempt . " lines.\n";

open out2, ">$oboFile" or die "Cannot open output file $oboFile\n";
my @owlData;
my $final1='';
my $header='';
my $line=0;
my $namespace;
my $ontology;
foreach (@tempt) {
	$line++;
	$final1 = $final1 . $_ . "\n";;
	if ($_ =~ m/xmlns=/) {
		my @atr = split(/"/, $_);
		my @atr2 = split(/\//, $atr[1]);
		$atr2[-1] =~ s/#//g;
		if ($atr2[-1] =~ m/./) {
			my @lt = split (/\./, $atr2[-1]);
			$lt[0] =~ s/&obo;//g;
			$namespace = $lt[0];
		}
		else {
			$atr2[-1] =~ s/&obo;//g;
			$namespace = $atr2[-1];
		}
	}
	if ($_ =~ m/owl:Ontology rdf:about=/) {
		my @atr = split(/"/, $_);
		if ($atr[1] !~ /^\s*$/) {
			my @atr2 = split(/\//, $atr[1]);
			$atr2[-1] =~ s/#//g;
			$atr2[-1] =~ s/&obo;//g;
			if ($atr2[-1] =~ m/./) {
				my @lt = split (/\./, $atr2[-1]);
				$ontology = $lt[0];
			}
			else {
				$ontology = $atr2[-1];
			}
		}
		else {
			$ontology = $namespace;
		}
	}	
	if ($_ =~ m/<\/owl:Ontology>/) {
		#print "Found the header, last line is $line\n";
		$header = $final1;
		last;
	}
}
#print the ontology and namespace tags
print out2 "ontology: $ontology\n";
print out2 "default-namespace: $namespace\n";


print "Continuing to blocks\n";
my @blocks;
my %terms;
my %typedefs;
$final1='';
for (my $i=$line; $i < scalar @tempt; $i++) {
	if (($tempt[$i] =~ /^\s*$/) or ($tempt[$i] =~ m/^\s+<!--/) or ($tempt[$i] =~ m/^<!--/) or ($tempt[$i] =~ m/\/\/\s/) or ($tempt[$i] =~ m/\/\/\//) or ($tempt[$i] =~ m/^\s+-->/) or ($tempt[$i] =~ m/^\s+\/\//) or ($tempt[$i] =~ m/rdf:RDF/))  {
		next;
	}
	else {
		my @data = split(/\s+/, $tempt[$i]);
		if ($tempt[$i] =~ m/\/>/) {
			if ($tempt[$i] =~ m/<owl:ObjectProperty rdf:about=/) {
				my @temp = split(/"/,$tempt[$i]);
				my @temp2 = split(/\//,$temp[1]);
				if ($temp2[-1] =~ m/topObjectProperty/){
					#do nothing
				}
				else {
					$temp2[-1] =~ s/_/:/g;
					$temp2[-1] =~ s/#//g;
					$temp2[-1] =~ s/&obo;//g;
					my $str	= "id: $temp2[-1]\n";
					push @{$typedefs{$temp2[-1]}}, "$str";
				}
			}
			elsif ($tempt[$i] =~ m/<owl:ObjectProperty rdf:ID=/) {
				my @temp = split(/"/,$tempt[$i]);
				my $str	= "id: $temp[1]\n";
				push @{$typedefs{$temp[1]}}, "$str";
			}
			elsif ($tempt[$i] =~ m/<owl:Class rdf:about=/) {
				my @temp = split(/"/,$tempt[$i]);
				if ($temp[1] =~ m/#/) {
					my @temp2 = split(/#/, $temp[1]);
					$temp2[1] =~ s/_/:/g;
					$temp2[1] =~ s/&obo;//g;
					my $str	= "id: $temp2[1]\n";
					push @{$terms{$temp2[1]}}, "$str";
				}
				else {
					my @temp2 = split(/\//,$temp[1]);
					$temp2[-1] =~ s/_/:/g;
					$temp2[-1] =~ s/&obo;//g;
					my $str	= "id: $temp2[-1]\n";
					push @{$terms{$temp2[-1]}}, "$str";
				}
			}
			elsif ($tempt[$i] =~ m/<owl:Class rdf:ID=/) {
				my @temp = split(/"/,$tempt[$i]);
				print "In here for class $temp[1]\n";
				my $str	= "id: $temp[1]\n";
				push @{$terms{$temp[1]}}, "$str";
			}
			next;
		}
		elsif ($tempt[$i] !~ m/\/>/) {
			my $string = $tempt[$i]. "\n";
			my $data = $tempt[$i];
			my $j;
			my $times=1;
			foreach ($j=$i+1; $j < scalar @tempt; $j++) {
				$string = $string . $tempt[$j] . "\n";
				if ($tempt[$j] =~ m/$data[1]/) {
					if ($tempt[$j] =~ m/\/>/) {
						next;
					}
					else {
						$times++;
						next;
					}
				}
				my $search = substr($data[1], 1);
				$search = "</" . $search;
				if ($tempt[$j] =~ m/$search/) {
					$times--;
					if ($times==0) {
						last;
					}
					else {
						next;
					}
				}
			}
			#now we have the complete block
			#analyze the block
			my @toParse = split(/\n/, $string);
			if ($toParse[0] =~ m/<owl:Class rdf:about=/) {
				#found a class
				#find the id
				my @tag = split(/"/, $toParse[0]);
				my @tag2 = split(/\//, $tag[1]);
				$tag2[-1] =~ s/_/:/g;
				$tag2[-1] =~ s/#//g;
				$tag2[-1] =~ s/&obo;//g;
				push @{$terms{$tag2[-1]}}, "id: $tag2[-1]";
				foreach (my $k = 1; $k < scalar @toParse; $k++) {
					if ($toParse[$k] =~ m/<rdfs:isDefinedBy rdf:resource/) {
						my @what = split(/"/, $toParse[$k]);
						my @what2 = split(/:/, $what[1]);
						my $def = "def: $what2[-1]";
					}
					elsif ($toParse[$k] =~ m/<obo:IAO_0000115/) {
						my $def='';
						if ($toParse[$k] =~ m/<\/obo:IAO_0000115>/) {
							my @what = split('>', $toParse[$k]);
							my @what2 = split('<', $what[1]);
							$def="\"$what2[0]\"";
						}
						else {
							my $block=$toParse[$k];
							foreach (my $p = $k+1; $p < scalar @toParse; $p++) {
								$block = $block . $toParse[$p];
								if ($toParse[$p] =~ m/<\/obo:IAO_0000115>/) {
									last;
								}
							}
							my @sth = split (/>/, $block);
							my @st2 = split (/</, $sth[1]);
							$def = "\"$st2[0]\"";
						}
						my $found = 0;
						foreach (my $l = 1; $l < scalar @toParse; $l++) {
							if ($toParse[$l] =~ m/<obo:IAO_0000119/) {
								if ($toParse[$l] =~ m/<\/obo:IAO_0000119>/) {
									my @tt = split(/>/, $toParse[$l]);
									my @tt1 = split(/</, $tt[1]);
									$def = $def . " \[$tt1[0]\]";
									$found = 1;
									last;
								}
								else {
									my $block = $toParse[$l];
									foreach (my $a = $l+1; $a < scalar @toParse; $a++) {
										$block = $block . $toParse[$a];
										if ($toParse[$a] =~ m/<\/obo:IAO_0000119>/) {
											last;
										}
									}
									my @tt = split(/>/, $block);
									my @tt1 = split(/</, $tt[1]);
									$def = $def . " \[$tt1[0]\]";
									$found = 1;
									last;
								}
							}
						}
						if ($found == 0) {
							foreach (my $l = 1; $l < scalar @toParse; $l++) {
								if ($toParse[$l] =~ m/<obo:IAO_0000412 rdf:resource/) {
									my @tt = split(/"/, $toParse[$l]);
									$def = $def . " \[$tt[1]\]";
									$found = 1;
									last;
								}
							}
						}
						if ($found ==0) {
							$def = $def . " \[fromOwl:fromOwl\]";
						}
						push @{$terms{$tag2[-1]}}, "def: $def";
					}
					elsif ($toParse[$k] =~ m/<rdfs:subClassOf rdf:resource/) {
						my @what = split(/"/, $toParse[$k]);
						my @what2 = split(/\//, $what[1]);
						if ($what2[-1] =~ m/ObsoleteClass/) {
							push @{$terms{$tag2[-1]}}, "is_obsolete: true";
						}
						else {
							$what2[-1] =~ s/_/:/g;
							$what2[-1] =~ s/#//g;
							$what2[-1] =~ s/&obo;//g;
							push @{$terms{$tag2[-1]}}, "is_a: $what2[-1] !";
						}
					}
					elsif ($toParse[$k] =~ m/<rdfs:label>/) {
						my @what = split('>', $toParse[$k]);
						my @what2 = split('<', $what[1]);
						my $lab="$what2[0]";
						push @{$terms{$tag2[-1]}}, "name: $lab";
					}
					elsif ($toParse[$k] =~ m/<rdfs:label/) {
						my @block;
						push (@block, $toParse[$k]);
						for (my $p = $k+1; $p < scalar @toParse; $p++) {
							push (@block, $toParse[$p]);
							if ($toParse[$p] =~ m/<\/rdfs:label>/) {
								last;
							}
						}
						my $new='';
						foreach (@block) {
							chomp($_);
							$new = $new . $_;
						}
						my @what = split('>', $new);
						my @what2 = split('<', $what[1]);
						my $lab="$what2[0]";
						push @{$terms{$tag2[-1]}}, "name: $lab";
					}
					elsif ($toParse[$k] =~ m/<owl:disjointWith /) {
						my @what = split(/"/, $toParse[$k]);
						my @what2 = split(/\//, $what[1]);
						$what2[-1] =~ s/_/:/g;
						$what2[-1] =~ s/#//g;
						$what2[-1] =~ s/&obo;//g;
						push @{$terms{$tag2[-1]}}, "disjoint_from: $what2[-1] !";
					}
					elsif ($toParse[$k] =~ m/<owl:disjointWith>/) {
						my $block = "$toParse[$k]\n";
						my $ll=0;
						for (my $l=$k+1; $l < scalar @toParse; $l++) {
							$ll++;
							if ($toParse[$l] =~ m/<\/owl:disjointWith>/) {
								$block = $block . "$toParse[$l]\n";
								last;
							}
							else {
								$block = $block . "$toParse[$l]\n";
							}
						}
						$k = $k + $ll;
						my @new = split (/\n/, $block);
						foreach (@new) {
							if ($_ =~ m/<owl:Class rdf:ID/) {
								my @what = split(/"/, $_);
								$what[1] =~ s/_/:/g;
								$what[1] =~ s/#//g;
								$what[1] =~ s/&obo;//g;
								push @{$terms{$tag2[-1]}}, "disjoint_from: $what[1] !";
							}
						}
					}
					elsif ($toParse[$k] =~ m/<obo:IAO_0000118 rdf:datatype=/) {
						my @what = split('>', $toParse[$k]);
						my @what2 = split('<', $what[1]);
						my $lab="$what2[0]";
						push @{$terms{$tag2[-1]}}, "alt_id: $lab";
					}
					elsif ($toParse[$k] =~ m/<owl:Restriction>/) {
						my $rel='';
						my $r = $k+1;
						if ($toParse[$r] =~ m/<owl:onProperty rdf:resource/) {
							my @what = split (/"/, $toParse[$r]);
							my @what2 = split (/\//, $what[1]);
							$what2[-1] =~ s/_/:/g;
							$what2[-1] =~ s/#//g;
							$what2[-1] =~ s/&obo;//g;
							$rel = "relationship: $what2[-1] ";
							my $w = $r + 1;
							if ($toParse[$w] =~ m/<owl:someValuesFrom rdf:resource="http:\/\/www.w3.org\/2001\/XMLSchema/) {
								#do nothing
							}
							elsif ($toParse[$w] =~ m/<owl:someValuesFrom rdf:resource/) {
								my @whatt = split (/"/, $toParse[$w]);
								my @whatt2 = split (/\//, $whatt[1]);
								$whatt2[-1] =~ s/_/:/g;
								$whatt2[-1] =~ s/#//g;
								$whatt2[-1] =~ s/&obo;//g;
								$rel = $rel . "$whatt2[-1] !";
								push @{$terms{$tag2[-1]}}, "$rel";
								$k = $w;
							} 
						}
					}
					else {
						$toParse[$k] =~ s/^\s+//;
						$toParse[$k] =~ s/\s+$//;
						if (($toParse[$k] eq "</owl:Class>") or ($toParse[$k] eq "</owl:Restriction>") or($toParse[$k] eq "</rdfs:subClassOf>") or($toParse[$k] eq "<rdfs:subClassOf>") or($toParse[$k] eq "<owl:Class>") or($toParse[$k] eq "</owl:someValuesFrom>") or ($toParse[$k] eq "<owl:someValuesFrom>") or ($toParse[$k] eq "</owl:equivalentClass>") or ($toParse[$k] eq "<owl:equivalentClass>") or ($toParse[$k] =~ m/<obo:IAO_0000119/)) {
							#don't print anything, these tags have already been converted
						}
						else {
							print outFile "Line $i: $toParse[$k]\n";
					}
				}
			}
		}
		elsif ($toParse[0] =~ m/<owl:Class rdf:ID=/) {
				my @temp = split(/"/,$toParse[0]);
				print "out of quotes: $temp[1]\n";
				$temp[1] =~ s/_/:/g;
				$temp[1] =~ s/#//g;
				$temp[1] =~ s/&obo;//g;
				my $str	= "id: $temp[1]\n";
				push @{$terms{$temp[1]}}, "$str";
			}
		elsif ($toParse[0] =~ m/<owl:ObjectProperty rdf:ID=/) {
				my @temp = split(/"/,$toParse[0]);
				$temp[1] =~ s/_/:/g;
				$temp[1] =~ s/#//g;
				$temp[1] =~ s/&obo;//g;
				my $str	= "id: $temp[1]\n";
				push @{$typedefs{$temp[1]}}, "$str";
			}
			elsif ($toParse[0] =~ m/<owl:ObjectProperty rdf:about/) {
				#found a property
				#find the id
				my @ttag = split(/"/, $toParse[0]);
				my @ttag2 = split(/\//, $ttag[1]);
				$ttag2[-1] =~ s/_/:/g;
				$ttag2[-1] =~ s/#//g;
				$ttag2[-1] =~ s/&obo;//g;
				push @{$typedefs{$ttag2[-1]}}, "id: $ttag2[-1]";
				foreach (my $k = 1; $k < scalar @toParse; $k++) {
					if ($toParse[$k] =~ m/<rdfs:isDefinedBy rdf:resource/) {
						my @what = split(/"/, $toParse[$k]);
						my @what2 = split(/:/, $what[1]);
						my $def = "def: $what2[-1]";
					}
					elsif ($toParse[$k] =~ m/<obo:IAO_0000115/) {
						my $def='';
						if ($toParse[$k] =~ m/<\/obo:IAO_0000115>/) {
							my @what = split('>', $toParse[$k]);
							my @what2 = split('<', $what[1]);
							$def="\"$what2[0]\"";
						}
						else {
							my $block=$toParse[$k];
							foreach (my $p = $k+1; $p < scalar @toParse; $p++) {
								$block = $block . $toParse[$p];
								if ($toParse[$p] =~ m/<\/obo:IAO_0000115>/) {
									#$k = $p;
									last;
								}
							}
							my @sth = split (/>/, $block);
							my @st2 = split (/</, $sth[1]);
							$def = "\"$st2[0]\"";
						}
						my $found = 0;
						foreach (my $l = 1; $l < scalar @toParse; $l++) {
							if ($toParse[$l] =~ m/<obo:IAO_0000119/) {
								if ($toParse[$l] =~ m/<\/obo:IAO_0000119>/) {
									my @tt = split(/>/, $toParse[$l]);
									my @tt1 = split(/</, $tt[1]);
									$def = $def . " \[$tt1[0]\]";
									$found = 1;
									last;
								}
								else {
									my $block = $toParse[$l];
									foreach (my $a = $l+1; $a < scalar @toParse; $a++) {
										$block = $block . $toParse[$a];
										if ($toParse[$a] =~ m/<\/obo:IAO_0000119>/) {
											last;
										}
									}
									my @tt = split(/>/, $block);
									my @tt1 = split(/</, $tt[1]);
									$def = $def . " \[$tt1[0]\]";
									$found = 1;
									last;
								}
							}
						}
						if ($found == 0) {
							foreach (my $l = 1; $l < scalar @toParse; $l++) {
								if ($toParse[$l] =~ m/<obo:IAO_0000412 rdf:resource/) {
									my @tt = split(/"/, $toParse[$l]);
									$def = $def . " \[$tt[1]\]";
									$found = 1;
									last;
								}
							}
						}
						if ($found ==0) {
							$def = $def . " \[fromOwl:fromOwl\]";
						}
						push @{$typedefs{$ttag2[-1]}}, "def: $def";
					}
					elsif ($toParse[$k] =~ m/<rdfs:subPropertyOf rdf:resource/) {
						my @what = split(/"/, $toParse[$k]);
						my @what2 = split(/\//, $what[1]);
						if ($what2[-1] =~ m/topObjectProperty/){
							#do nothing
						}
						else {
							$what2[-1] =~ s/_/:/g;
							$what2[-1] =~ s/#//g;
							$what2[-1] =~ s/&obo;//g;
							push @{$typedefs{$ttag2[-1]}}, "is_a: $what2[-1] !";
						}
					}
					elsif ($toParse[$k] =~ m/<rdfs:label>/) {
						my @what = split('>', $toParse[$k]);
						my @what2 = split('<', $what[1]);
						my $lab="$what2[0]";
						push @{$typedefs{$ttag2[-1]}}, "name: $lab";
					}
					elsif ($toParse[$k] =~ m/<rdfs:label/) {
						my @block;
						push (@block, $toParse[$k]);
						for (my $p = $k+1; $p < scalar @toParse; $p++) {
							push (@block, $toParse[$p]);
							if ($toParse[$p] =~ m/<\/rdfs:label>/) {
								last;
							}
							#$j = $p;
						}
						my $new='';
						foreach (@block) {
							chomp($_);
							$new = $new . $_;
						}
						my @what = split('>', $new);
						my @what2 = split('<', $what[1]);
						my $lab="$what2[0]";
						push @{$typedefs{$ttag2[-1]}}, "name: $lab";
					}
					elsif ($toParse[$k] =~ m/<obo:IAO_0000118 rdf:datatype=/) {
						my @what = split('>', $toParse[$k]);
						my @what2 = split('<', $what[1]);
						my $lab="$what2[0]";
						push @{$typedefs{$ttag2[-1]}}, "alt_id: $lab";
					}
					elsif ($toParse[$k] =~ m/<rdf:type rdf:resource="http:\/\/www.w3.org\/2002\/07\/owl#TransitiveProperty"\/>/) {
						push @{$typedefs{$ttag2[-1]}}, "is_transitive: true";
					}
					elsif (($toParse[$k] =~ m/<rdf:type rdf:resource/) && ($toParse[$k] =~ m/TransitiveProperty/)) {
						push @{$typedefs{$ttag2[-1]}}, "is_transitive: true";
					}
					elsif (($toParse[$k] =~ m/<rdf:type rdf:resource/) && ($toParse[$k] =~ m/ReflexiveProperty/)) {
						push @{$typedefs{$ttag2[-1]}}, "is_reflexive: true";
					}
					elsif (($toParse[$k] =~ m/<rdf:type rdf:resource/) && ($toParse[$k] =~ m/SymmetricProperty/)) {
						push @{$typedefs{$ttag2[-1]}}, "is_symmetric: true";
					}
					elsif ($toParse[$k] =~ m/<owl:inverseOf rdf:resource=/) {
						my @ekt = split(/"/, $toParse[$k]);
						my @ekt2 = split (/\//, $ekt[1]);
						$ekt2[-1] =~ s/_/:/g;
						$ekt2[-1] =~ s/#//g;
						$ekt2[-1] =~ s/&obo;//g;
						push @{$typedefs{$ttag2[-1]}}, "inverse_of: $ekt2[-1] !";
					}
					else {
						$toParse[$k] =~ s/^\s+//;
						$toParse[$k] =~ s/\s+$//;
						if (($toParse[$k] eq "</owl:ObjectProperty>") or ($toParse[$k] =~ m/<obo:IAO_0000119/)) {
							#don't print anything, these are closing tags
						}
						else {
							print outFile "Line $i: $toParse[$k]\n";
						}
					}
				}
			}
			$i = $j;
			#next;
		}
	}
}

my %addTerms;
my %addTypedefs;
foreach my $key (sort keys %terms) {
	print out2 "\n[Term]\n";
	foreach my $raw_data (@{$terms{$key}}) {
		if ($raw_data =~ m/id: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			my $found=0;
			foreach my $raw2 (@{$terms{$key}}) {
				if ($raw2 =~ m/name: /) {
					chomp($raw2);
					print out2 "$raw2\n";
					$found=1;
					last;
				}
			}
			if (($found ==0) and ($choice eq 'y')) {
				my @kati = split(/\s/, $raw_data);
				chomp($kati[1]);
				print out2 "name: $kati[1]\n";
			}
			last;
		}
	}
	foreach my $raw_data (@{$terms{$key}}) {
		if ($raw_data =~ m/alt_id: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			last;
		}
	}
	foreach my $raw_data (@{$terms{$key}}) {
		if ($raw_data =~ m/def: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			last;
		}
	}
	foreach my $raw_data (@{$terms{$key}}) {
		if ($raw_data =~ m/is_a: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			my @kat = split(/\s/, $raw_data);
			if ((!exists $terms{$kat[1]}) and (!exists $addTerms{$kat[1]})) {
				push @{$addTerms{$kat[1]}}, "id: $kat[1]";
				push @{$addTerms{$kat[1]}}, "name: $kat[1]";
			}
			last;
		}
	}
	foreach my $raw_data (@{$terms{$key}}) {
		if ($raw_data =~ m/disjoint_from: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			last;
		}
	}
	foreach my $raw_data (@{$terms{$key}}) {
		if ($raw_data =~ m/relationship: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			my @pint = split(/\s/, $raw_data);
			if (!($typedefs{$pint[1]})) {
				push @{$typedefs{$pint[1]}}, "id: $pint[1]";
				push @{$typedefs{$pint[1]}}, "name: $pint[1]";
			}
		}
	}
	foreach my $raw_data (@{$terms{$key}}) {
		if ($raw_data =~ m/is_obsolete: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			my @pint = split(/\s/, $raw_data);
			last;
		}
	}
	

}

foreach my $key (sort keys %addTerms) {
	if (!exists $terms{$key}) {
		print out2 "\n[Term]\n";
		foreach (@{$addTerms{$key}}) {
			chomp($_);
			print out2 "$_\n";
		}
	}
}

foreach my $key (sort keys %typedefs) {
	print out2 "\n[Typedef]\n";
	foreach my $raw_data (@{$typedefs{$key}}) {
		if ($raw_data =~ m/id: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			my $found=0;
			foreach my $raw2 (@{$typedefs{$key}}) {
				if ($raw2 =~ m/name: /) {
					chomp($raw2);
					print out2 "$raw2\n";
					$found=1;
					last;
				}
			}
			if (($found ==0) and ($choice eq 'y')) {
				my @kati = split(/\s/, $raw_data);
				chomp($kati[1]);
				print out2 "name: $kati[1]\n";
			}
			last;
		}
	}
	foreach my $raw_data (@{$typedefs{$key}}) {
		if ($raw_data =~ m/alt_id: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			last;
		}
	}
	foreach my $raw_data (@{$typedefs{$key}}) {
		if ($raw_data =~ m/def: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			last;
		}
	}
	foreach my $raw_data (@{$typedefs{$key}}) {
		if ($raw_data =~ m/is_reflexive: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			last;
		}
	}
	foreach my $raw_data (@{$typedefs{$key}}) {
		if ($raw_data =~ m/is_symmetric: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			last;
		}
	}
	foreach my $raw_data (@{$typedefs{$key}}) {
		if ($raw_data =~ m/is_transitive: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			last;
		}
	}
	foreach my $raw_data (@{$typedefs{$key}}) {
		if ($raw_data =~ m/is_a: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			my @kat = split(/\s/, $raw_data);
			if (!($typedefs{$kat[1]}) and !($addTypedefs{$kat[1]})) {
				push @{$addTypedefs{$kat[1]}}, "id: $kat[1]";
				push @{$addTypedefs{$kat[1]}}, "name: $kat[1]";
			}
			last;
		}
	}
	foreach my $raw_data (@{$typedefs{$key}}) {
		if ($raw_data =~ m/disjoint_from: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
			last;
		}
	}
	foreach my $raw_data (@{$typedefs{$key}}) {
		if ($raw_data =~ m/inverse_of: /) {
			chomp($raw_data);
			print out2 "$raw_data\n";
		}
	}
	

}

foreach my $key (sort keys %addTypedefs) {
	print out2 "\n[Typedef]\n";
	foreach (@{$addTypedefs{$key}}) {
		chomp($_);
		print out2 "$_\n";
	}
}


print "Done!\n";


