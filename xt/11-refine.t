use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Fasops;
use Path::Tiny;

my $result;

$result = test_app( 'App::Fasops' => [qw(refine t/example.fas -o stdout)] );
is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );

$result = test_app( 'App::Fasops' => [qw(refine t/refine.fas -o stdout)] );
is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 16, 'line count' );
like( ( split /\n\n/, $result->stdout )[0], qr{\-\-\-}s, 'dash added' );

my $section = ( split /\n\n/, $result->stdout )[1];
$section = join "", grep { !/^>/ } split( /\n/, $section );
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

$result = test_app( 'App::Fasops' => [qw(refine t/refine2.fas --quick --outgroup -o stdout)] );
is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 6, 'line count' );
is( length( ( grep {/\S/} split( /\n/, $result->stdout ) )[1] ), 19, 'outgroup trimmed' );

$result = test_app( 'App::Fasops' => [qw(refine t/refine2.fas -o stdout)] );
is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 6, 'line count' );
is( length( ( grep {/\S/} split( /\n/, $result->stdout ) )[1] ), 20, 'outgroup not trimmed' );

$result = test_app( 'App::Fasops' => [qw(refine t/refine.fas -p 2 -o stdout)] );
is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 16, 'line count' );
like( ( split /\n\n/, $result->stdout )[0], qr{\-\-\-}s, 'dash added' );

done_testing(11);
