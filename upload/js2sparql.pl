
BEGIN {
	push @INC, '/home/mironov/git/bgw';
}

use strict;
use warnings;
use Carp;

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};

# use IO::Handle;
# *STDOUT->autoflush(); # screws up logs ?
########################################################################################################################

use auxmod::SharedSubs qw( 
open_read
open_write
);

my ( $jspath, $qpath, $tpath ) = @ARGV; 
my ( $label, $qbegin, $qend ) = ('Qry', '<---', '--->');
my $indent = "\t";
my $tail =  ' \n' .  '"' . ' +' . "\n";
my $qbuff = '';
my $lbuff = "";
my $count = 0;
my $open = '<option value ="';
my $close = "</option>\n";
my $qno;
my $jsfh = open_read ( $jspath );
my $rex_dqs = qr/.*"(.+)"/xmso;

while ( <$jsfh> ) {
	my $line = $_;
	if ( $line =~ /\s*case\s+/xmso ) {
		my ($qid) = $line =~ $rex_dqs;
		$qbuff .= "$qbegin\n# $qid\n";
# 		next;
	}
# 	elsif ( $line =~ /(".+").+\+\s*$/xmso ) {
	elsif ( $line =~ /^\s+?.*?"(.+?)"\s*\S\s*$/xmso ) { # the regex is fine
# 		my ($string) = $line =~ $rex_dqs;
		my $string = $1;# print "string: $string\n";
# 		my ($sparql) = $string =~ /^(.+)\s*\\n\s*/xmso;
# 		$qbuff .= "$sparql\n";
		$qbuff .= $string =~ /^(.+)\s*\\n\s*/xmso ? "$1\n" : "$string\n";
		
	}
# 	elsif ( $line =~ /^\s*"\s*\}\s*\\n\s*;\s*$/ ) {
# 		$qbuff .= "}\n";
# 	}
	elsif ( $line =~ /\s*break;\s+/xmso ) {
		$qbuff .= $qend . "\n";
	}
	last if $line =~ /\s*default:\s+/xmso;
}
print $qbuff;
