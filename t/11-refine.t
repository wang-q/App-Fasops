use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Fasops;
use Path::Tiny;
use IPC::Cmd;

{
    my $result;

    $result = test_app( 'App::Fasops' => [qw(help refine)] );
    like( $result->stdout, qr{refine}, 'descriptions' );

    $result = test_app( 'App::Fasops' => [qw(refine t/example.fas --msa none -o stdout)] );
    is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );

    $result = test_app( 'App::Fasops' => [qw(refine t/example.fas --msa none -p 2 -o stdout)] );
    is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );

    $result
        = test_app( 'App::Fasops' => [qw(refine t/example.fas --msa none --chop 10 -o stdout)] );
    is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );
    like( ( split /\n\n/, $result->stdout )[2], qr{185276-185332}, 'new header' );   # 185273-185334
    like( ( split /\n\n/, $result->stdout )[2], qr{156668-156724}, 'new header' );   # 156665-156726
    like( ( split /\n\n/, $result->stdout )[2], qr{3670-3727},     'new header' );   # (-):3668-3730
    like( ( split /\n\n/, $result->stdout )[2], qr{2102-2159},     'new header' );   # (-):2102-2161
}

SKIP: {
    skip "mafft not installed", 11 unless IPC::Cmd::can_run('mafft');

    my $result;
    $result = test_app( 'App::Fasops' => [qw(refine t/example.fas --msa mafft -o stdout)] );
    is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 24, 'line count' );

    $result = test_app( 'App::Fasops' => [qw(refine t/refine.fas --msa mafft -o stdout)] );
    is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 16, 'line count' );
    like( ( split /\n\n/, $result->stdout )[0], qr{\-\-\-}s, 'dash added' );

    my $section = ( split /\n\n/, $result->stdout )[1];
    $section = join "", grep { !/^>/ } split( /\n/, $section );
    my $count = $section =~ tr/-/-/;
    is( $count, 11, 'count of dashes' );

    $result = test_app( 'App::Fasops' => [qw(refine t/refine.fas --msa mafft -o stdout)] );
    my $output = $result->stdout;
    $output =~ s/\-//g;
    $output =~ s/\s+//g;
    my $original = path("t/refine.fas")->slurp;
    $original =~ s/\-//g;
    $original =~ s/\s+//g;
    is( $output, $original, 'same without dashes' );

    $result = test_app(
        'App::Fasops' => [qw(refine t/refine2.fas --msa mafft --quick --outgroup -o stdout)] );
    is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 6, 'line count' );
    is( length( ( grep {/\S/} split( /\n/, $result->stdout ) )[1] ), 19, 'outgroup trimmed' );

    $result = test_app( 'App::Fasops' => [qw(refine t/refine2.fas --msa mafft -o stdout)] );
    is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 6, 'line count' );
    is( length( ( grep {/\S/} split( /\n/, $result->stdout ) )[1] ), 20, 'outgroup not trimmed' );

    $result = test_app( 'App::Fasops' => [qw(refine t/refine.fas -p 2 --msa mafft -o stdout)] );
    is( scalar( grep {/\S/} split( /\n/, $result->stdout ) ), 16, 'line count' );
    like( ( split /\n\n/, $result->stdout )[0], qr{\-\-\-}s, 'dash added' );
}

done_testing(19);
