# to be called from the orthagogue working  dir

use Carp;
use strict;
use warnings;
$Carp::Verbose = 1;

#~ my ( $o, $c ) = @ARGV;
my ( $file, $cpu ) = @ARGV;
#my @dirs = (
#'/norstore/user/mironov/workspace/orthagogue/0.9.9.3/2-set',
#'/norstore/user/mironov/workspace/orthagogue/0.9.9.3/3-set',
#'/norstore/user/mironov/workspace/orthagogue/0.9.9.3/4-set',
#'/norstore/user/mironov/workspace/orthagogue/0.9.9.3/5-set',
#'/norstore/user/mironov/workspace/orthagogue/0.9.9.3/6-set',
#'/norstore/user/mironov/workspace/orthagogue/0.9.9.3/7-set',
#);
my $cmd = "orthAgogue -i $file -o 50 -c $cpu -u ";

my $start = time;
#print "$cmd\n";
system ( $cmd );
my $end = time;
my $time_elapsed = $end -$start;
print "$cmd\n";
print "time elapsed: $time_elapsed $file\n";

#~ foreach ( @dirs ) {
	#~ my $start = time;
	#~ my $dir = "$_/default";
	#~ system ( "mkdir $dir" );
	#~ my $cmd = "./orthaGogue -i $_/goodProteins.blast -O $dir";
	#~ system ( $cmd );
	#~ my $end = time;
	#~ my $time_elapsed = $end -$start;
	#~ my $time = chdir $dir; # shell 'cd' does not work here?
	#~ system ( 'pwd' );
	#~ print "time elapsed: $time_elapsed $dir\n";
#~ }
