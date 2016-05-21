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

done_testing(3);
