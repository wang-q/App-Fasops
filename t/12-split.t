use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Fasops;
use App::Fasops::Common;

my $result = test_app( 'App::Fasops' => [qw(help split)] );
like( $result->stdout, qr{split}, 'descriptions' );

$result = test_app( 'App::Fasops' => [qw(split t/example.fas -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );

my Path::Tiny $tempdir = Path::Tiny::tempdir();
$result = test_app( 'App::Fasops' => [ qw(split t/example.fas --chr -o ), $tempdir->stringify ] );
is($result->stdout, "" );
is($result->stderr, "" );
ok( Path::Tiny::path( $tempdir, "I.fas" )->is_file, "file exists" );
undef $tempdir;

done_testing(5);
