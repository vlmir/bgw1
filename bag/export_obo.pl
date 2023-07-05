BEGIN {
	unshift @INC, '/norstore/user/mironov/workspace/ONTO-PERL-1.29/lib';
}
use Carp;
use strict;
use warnings;
use OBO::Parser::OBOParser;

my ($in_file, $out_file) = @ARGV;

my $obo_parser = OBO::Parser::OBOParser->new();
my $onto = $obo_parser->work($in_file);
print_obo ($onto, $out_file );
sub print_obo {
	my ($onto, $path) = @_;
	open( FH, ">$path" ) || croak "Error  exporting: $path", $!;
	$onto->export( \*FH );
	select( ( select(FH), $| = 1 )[0] );
	close FH;
}
