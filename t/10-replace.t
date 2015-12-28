use Test::More tests => 5;
use App::Cmd::Tester;

use App::Fasops;

my $result = test_app( 'App::Fasops' => [qw(replace t/example.fas t/replace.tsv -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 32, 'line count' );
like( ( split /\n\n/, $result->stdout )[2], qr{\>S288c.+\>query}s, 'correct name order' );

$result = test_app( 'App::Fasops' => [qw(replace t/example.fas t/replace.fail.tsv -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );
unlike( $result->stdout, qr{target|query}, 'not replaced' );
like( $result->stderr, qr{multiply records}, 'error message' );
