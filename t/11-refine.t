use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Fasops;

my $result;

$result = test_app( 'App::Fasops' => [qw(help refine)] );
like( $result->stdout, qr{refine}, 'descriptions' );

$result = test_app(
    'App::Fasops' => [qw(refine t/example.fas --msa none -o stdout)] );
is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );

$result = test_app(
    'App::Fasops' => [qw(refine t/example.fas --msa none -p 2 -o stdout)] );
is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );

$result
    = test_app(
    'App::Fasops' => [qw(refine t/example.fas --msa none --chop 10 -o stdout)]
    );
is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );
like( ( split /\n\n/, $result->stdout )[2], qr{185270-185332}, 'new header' );

done_testing();
