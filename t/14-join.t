use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Fasops;

my $result = test_app( 'App::Fasops' => [qw(help join)] );
like( $result->stdout, qr{join}, 'descriptions' );

$result = test_app(
    'App::Fasops' => [
        qw(join t/S288cvsRM11_1a.slice.fas t/S288cvsYJM789.slice.fas t/S288cvsSpar.slice.fas -n S288c -o stdout)
    ]
);
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 8, 'line count' );
like( $result->stdout, qr{S288c.+RM11_1a.+YJM789.+Spar}s, 'name list' );

done_testing(3);
