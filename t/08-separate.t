use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Fasops;

my $result = test_app( 'App::Fasops' => [qw(help separate)] );
like( $result->stdout, qr{separate}, 'descriptions' );

$result = test_app( 'App::Fasops' => [qw(separate t/example.fas -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );

$result = test_app( 'App::Fasops' => [qw(separate t/example.fas --nodash --rc -o stdout)] );
unlike( $result->stdout, qr{\(\-\)}, 'strands' );
unlike( $result->stdout, qr{T\-C},   'nodash' );

done_testing(4);
