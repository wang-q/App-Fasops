use Test::More tests => 3;
use App::Cmd::Tester;

use App::Fasops;

my $result = test_app( 'App::Fasops' => [qw(separate t/example.fas -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );

$result = test_app( 'App::Fasops' => [qw(axt2fas t/example.fas --nodash --rc -o stdout)] );
unlike( $result->stdout, qr{\(\-\)}, 'strands' );
unlike( $result->stdout, qr{T\-C},   'nodash' );
