use Test::More;

BEGIN {
    use_ok( 'App::Fasops::Common' );
}

{
    print "#seq_length\n";

    my @data = (
        [qw{ AAAA 4 }], [qw{ CCCC 4 }],
        [qw{ TAGGGATAACAGGGTAAT 18 }],
        [qw{ GCAN--NN--NNTGC 11 }],
    );

    for my $i ( 0 .. @data - 1 ) {
        my ( $ori, $expected ) = @{ $data[$i] };
        my $result = App::Fasops::Common::seq_length($ori);
        is( $result, $expected, "seq_length $i" );
    }
}

{
    print "#revcom\n";

    my @data = (
        [qw{ AAaa ttTT }],
        [qw{ CCCC GGGG }],
        [qw{ TAGGGATAACAGGGTAAT ATTACCCTGTTATCCCTA }],    # I-Sce I endonuclease
        [qw{ GCANNNNNTGC GCANNNNNTGC }],                  # BstAP I
    );

    for my $i ( 0 .. @data - 1 ) {
        my ( $ori, $expected ) = @{ $data[$i] };
        my $result = App::Fasops::Common::revcom($ori);
        is( $result, $expected, "revcom $i" );
    }
}

{
    print "#indel_intspan\n";

    my @data = (
        [ "ATAA",            "-" ],
        [ "CcGc",            "-" ],
        [ "TAGggATaaC",      "-" ],
        [ "C-Gc",            "2" ],
        [ "C--c",            "2-3" ],
        [ "---c",            "1-3" ],
        [ "C---",            "2-4" ],
        [ "GCaN--NN--NNNaC", "5-6,9-10" ],
    );

    for my $i ( 0 .. $#data ) {
        my ( $ori, $expected ) = @{ $data[$i] };
        my $result = App::Fasops::Common::indel_intspan($ori);
        print "original: $ori\n";
        is( $result->runlist, $expected, "indel_intspan $i" );
    }
}

{
    print "#calc_gc_ratio\n";

    my @data = (
        [ "ATAA",            0 ],
        [ "AtaA",            0 ],
        [ "CCGC",            1 ],
        [ "CcGc",            1 ],
        [ "TAGggATaaC",      0.4 ],
        [ "GCaN--NN--NNNaC", 0.6 ],
    );

    for my $i ( 0 .. $#data ) {
        my ( $ori, $expected ) = @{ $data[$i] };
        my $result = App::Fasops::Common::calc_gc_ratio( [$ori] );
        print "original: $ori\n";
        is( $result, $expected, "calc_gc_ratio $i" );
    }
}

done_testing();
