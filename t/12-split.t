use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Fasops;

my $result = test_app( 'App::Fasops' => [qw(help split)] );
like( $result->stdout, qr{split}, 'descriptions' );

done_testing(1);
