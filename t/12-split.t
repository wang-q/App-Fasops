use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Fasops;

my $result = test_app( 'App::Fasops' => [qw(help split)] );
like( $result->stdout, qr{split}, 'descriptions' );

$result = test_app( 'App::Fasops' => [qw(split t/example.fas -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );

$result = test_app( 'App::Fasops' => [qw(split t/example.fas --chr -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );

done_testing(3);
