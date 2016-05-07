use Test::More;
use App::Cmd::Tester;

use App::Fasops;

my $result = test_app( 'App::Fasops' => [qw(help refine)] );
like( $result->stdout, qr{refine}, 'descriptions' );

done_testing(1);
