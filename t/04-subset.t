use Test::More tests => 3;
use App::Cmd::Tester;

use App::Fasops;

my $result = test_app(
    'App::Fasops' => [qw(subset t/example.fas t/example.name.list -o stdout)] );

is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 12, 'line count' );

like( ( split /\n\n/, $result->stdout )[0],
    qr{\>Spar.+\>YJM789}s, 'correct name order' );
unlike( ( split /\n\n/, $result->stdout )[0],
    qr{\>YJM789.+\>Spar}s, 'incorrect name order' );
