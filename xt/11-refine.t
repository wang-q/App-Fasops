use Test::More;
use App::Cmd::Tester;

use App::Fasops;
use Path::Tiny;

my $result = test_app( 'App::Fasops' => [qw(refine t/example.fas -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );

$result = test_app( 'App::Fasops' => [qw(refine t/refine.fas -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 16, 'line count' );
like( ( split /\n\n/, $result->stdout )[0], qr{\-\-\-}s, 'dash added' );

my $section = ( split /\n\n/, $result->stdout )[1];
$section = join "", grep { ! /^>/ } split(/\n/, $section);
my $count = $section =~ tr/-/-/;
is( $count, 11, 'count of dashes' );

$result = test_app( 'App::Fasops' => [qw(refine t/refine.fas --msa muscle -o stdout)] );
my $output = $result->stdout;
$output =~ s/\-//g;
$output =~ s/\s+//g;
my $original = path("t/refine.fas")->slurp;
$original =~ s/\-//g;
$original =~ s/\s+//g;
is( $output, $original, 'same without dashes' );

done_testing(5);
