use Test::More;
use App::Cmd::Tester;

use App::Fasops;

my $result = test_app( 'App::Fasops' => [qw(help links)] );
like( $result->stdout, qr{links}, 'descriptions' );

$result = test_app( 'App::Fasops' => [qw(links t/example.fas -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 18, 'line count' );
like( $result->stdout, qr{S288c.+\tYJM789}, 'name list' );

done_testing(3);
