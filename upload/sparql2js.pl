
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

use IO::Handle;
*STDOUT->autoflush(); # screws up logs ?
########################################################################################################################

use auxmod::SharedSubs qw( 
open_read
open_write
benchmark
__date
);

use auxmod::SharedVars qw(
$download_dir
$projects_dir
%uris
);
my ( $qpath, $tpath ) = @ARGV; 
my ( $label, $qbegin, $qend ) = ('Qry', '<---', '--->');
my $indent = "\t";
my $tail =  ' \n' .  '"' . ' +' . "\n";
my $qbuff = $indent . "{\n";
my $lbuff = "";
my $count = 0;
my $open = '<option value ="';
my $close = "</option>\n";
my $qno;
my $FH = open_read ( $qpath );
while ( <$FH> ) {
	chomp;
	my $line = $_;
# 	next if substr ( $line, 0, 4 ) eq $qend;
	my $indent = "\t\t";
	if ( substr ( $line, 0, 4 ) eq $qbegin ) {
# 	print "qbuff: $qbuff\n";
# 		$qbuff =~ s/^(.+)\s*\+\s*$/$1;/ if $1;
# 		$qbuff .= $indent . "break;\n" if $count;
		$count++;
		$qno = $count < 10 ? '0'.$count : $count;
		$qbuff .= $indent . 'case "' . $label . $qno . '":' . "\n";
# 		$qbuff .= $indent . "idQ.value = " . '""' . " +\n";
		$qbuff .= $indent . "idQ.value = \n";
# 		next;
	}
	elsif ( $line =~ /^\#\s+NAME\s*:\s+(\w+.*\w+)/xmso ) {
		$qbuff .= $indent . '"' . $line . $tail;
		my $name = ucfirst ( $1 );
		$lbuff .= $open . $label . $qno . '">' . $label .' ' . $qno . '. ' . $name . $close;
	}
# 	if ( $line =~ /^\s*switch/xmso ) {
# 		print '{' . $tail . "\n" . $qbuff . '}' . $tail . "\n";
# 	}
	elsif ( substr ( $line, 0, 4 ) eq $qend ) {
# 		print "qbuff: $qbuff\n";
		substr ( $qbuff, -2, 2, ';' );
		$qbuff .= "\n" . $indent . "break;\n";
# 		next;
	 }
	else { $qbuff .= $indent . '"' . $line . $tail };
}
close ( $FH );
$qbuff .= $indent . "default:\n";
$qbuff .= $indent . "break;\n";
$qbuff .= $indent . "}\n";
# print $qbuff;
# print $lbuff;

$FH = open_read ( $tpath );
while ( <$FH> ) {
	my $line = $_;
	print $line;
	print $qbuff if $line =~ /^\sswitch\s*\(\s*idExample/xmso;
# 	print $lbuff if $line =~ /^<select\sname/xmso;
	print $lbuff if $line =~ /^<option\svalue/xmso;
}
close $FH;
