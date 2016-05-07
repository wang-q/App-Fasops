use Test::More tests => 9;

BEGIN {
    use_ok( 'App::Fasops::Common' );
}

{
    print "#seq_length\n";

    my @seqs = (
        [qw{ AAAA 4 }], [qw{ CCCC 4 }],
        [qw{ TAGGGATAACAGGGTAAT 18 }],
        [qw{ GCAN--NN--NNTGC 11 }],
    );

    for my $i ( 0 .. @seqs - 1 ) {
        my ( $ori, $expected ) = @{ $seqs[$i] };
        my $result = App::Fasops::Common::seq_length($ori);
        is( $result, $expected, "seq_length_$i" );
    }
}

{
    print "#revcom\n";

    my @seqs = (
        [qw{ AAaa ttTT }],
        [qw{ CCCC GGGG }],
        [qw{ TAGGGATAACAGGGTAAT ATTACCCTGTTATCCCTA }],    # I-Sce I endonuclease
        [qw{ GCANNNNNTGC GCANNNNNTGC }],                  # BstAP I
    );

    for my $i ( 0 .. @seqs - 1 ) {
        my ( $ori, $expected ) = @{ $seqs[$i] };
        my $result = App::Fasops::Common::revcom($ori);
        is( $result, $expected, "revcom_$i" );
    }
}
