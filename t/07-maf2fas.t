use Test::More tests => 3;
use App::Cmd::Tester;

use App::Fasops;

my $result = test_app( 'App::Fasops' => [qw(maf2fas t/example.maf -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 16, 'line count' );
like( $result->stdout, qr{S288c\.VIII.+RM11_1a\.scaffold_12.+Spar\.gi_29362578}s, 'name list' );

$result = test_app( 'App::Fasops' => [qw(maf2fas t/example.maf -l 50 -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 8, 'line count' );
