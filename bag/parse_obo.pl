BEGIN {
	#~ unshift @INC, '/norstore/user/mironov/workspace/onto-perl/ONTO-PERL-1.37/lib';
	unshift @INC, '/norstore/project/ssb/workspace/onto-perl/lib';
}
use Carp;
use strict;
use warnings;
$Carp::Verbose = 1;
use OBO::Util::Ontolome;
use OBO::XO::OBO_ID_Term_Map;
use OBO::Parser::OBOParser;
use Data::Dumper;

my $start = `date`;
chomp $start;
my $obo_parser = OBO::Parser::OBOParser->new();
my ( $dir, $obo_file ) = @ARGV;

my $onto =  $obo_parser->work ( "$dir/$obo_file" );
my $end = `date`;
chomp $end;

my $format = 'rdf';
my $base  = 'http://www.semantic-systems-biology.org/';
my $export_path = "./$obo_file.$format";
open( OUT, "> $export_path" ) || croak "Failed to open for writing $export_path:  $!";
open( ERR, "> $export_path.err" ) || croak "Failed to open for writing $export_path.err:  $!";

$onto->export( $format, \*OUT,  \*ERR, $base, , 'SSB', 0, 1 );

