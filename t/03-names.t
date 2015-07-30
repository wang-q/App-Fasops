use Test::More tests => 3;
use App::Cmd::Tester;

use App::Fasops;

my $result = test_app( 'App::Fasops' => [qw(names t/example.fas -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 4, 'name count' );
like( $result->stdout, qr{S288C.+Spar}s, 'default commands outputs' );

$result = test_app( 'App::Fasops' => [qw(names t/example.fas -c -o stdout)] );
like( $result->stdout, qr{S288C\t3.+Spar\t3}s, 'default commands outputs' );
