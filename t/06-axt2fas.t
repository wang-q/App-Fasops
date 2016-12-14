use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Fasops;

my $result = test_app( 'App::Fasops' => [qw(help axt2fas)] );
like( $result->stdout, qr{axt2fas}, 'descriptions' );

$result = test_app( 'App::Fasops' => [qw(axt2fas t/example.axt -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 8, 'line count' );
like( $result->stdout, qr{target\.I.+query\.scaffold_14.+target\.I.+query.scaffold_17}s,
    'name list' );

$result = test_app( 'App::Fasops' => [qw(axt2fas t/example.axt -t S288c -q RM11_1a -l 1000 -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 4, 'line count' );
like( $result->stdout, qr{S288c\.I.+RM11_1a\.scaffold_17}s, 'change names' );

done_testing(5);
