use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Fasops;
use Spreadsheet::XLSX;

my $result = test_app( 'App::Fasops' => [qw(help xlsx)] );
like( $result->stdout, qr{xlsx}, 'descriptions' );

$result = test_app( 'App::Fasops' => [qw(xlsx)] );
like( $result->error, qr{need .+input file}, 'need infile' );

$result = test_app( 'App::Fasops' => [qw(xlsx t/not_exists)] );
like( $result->error, qr{doesn't exist}, 'infile not exists' );

my $temp = Path::Tiny->tempfile;
$result = test_app( 'App::Fasops' => [ qw(xlsx t/example.fas -o ), $temp->stringify ] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 3, 'line count' );
like( $result->stdout, qr{Section \[4}, 'sections writed' );

my $xlsx  = Spreadsheet::XLSX->new( $temp->stringify );
my $sheet = $xlsx->{Worksheet}[0];

# row-col
is( $sheet->{Cells}[1][1]{Val},  "G",  "Cell content 1" );
is( $sheet->{Cells}[22][3]{Val}, "I1", "Cell content 2" );

done_testing();
