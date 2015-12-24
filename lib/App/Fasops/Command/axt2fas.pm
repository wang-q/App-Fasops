package App::Fasops::Command::axt2fas;

use App::Fasops -command;

use constant abstract => 'convert axt to blocked fasta';

sub opt_spec {
    return (
        [ "outfile|o=s", "output filename" ],
        [   "length|l=i",
            "the threshold of alignment length, default is [1]",
            { default => 1 }
        ],
        [   "tname|t=s",
            "target name, default is [target]",
            { default => "target" }
        ],
        [   "qname|q=s",
            "query name, default is [query]",
            { default => "query" }
        ],
    );
}

sub usage_desc {
    my $self = shift;
    my $desc = $self->SUPER::usage_desc;    # "%c COMMAND %o"
    $desc .= " <infile>";
    return $desc;
}

sub description {
    my $desc;
    $desc
        .= "Convert UCSC axt pairwise alignment file to blocked fasta file.\n";
    $desc .= "\t<infile> is the path to axt file, .axt.gz is supported\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error("This command need a input file.") unless @$args;
    $self->usage_error("The input file [@{[$args->[0]]}] doesn't exist.")
        unless -e $args->[0];

    if ( $opt->{tname} ) {
        if ( $opt->{tname} !~ /^[\w]+$/ ) {
            $self->usage_error("[--tname] should be an alphanumeric value.");
        }
    }
    if ( $opt->{qname} ) {
        if ( $opt->{qname} !~ /^[\w]+$/ ) {
            $self->usage_error("[--qname] should be an alphanumeric value.");
        }
    }

    if ( !exists $opt->{outfile} ) {
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".fas";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    open my $out_fh, ">", $opt->{outfile};

    # read and write
    my $data = App::Fasops::parse_axt( $args->[0] );
    @{$data} = grep { $_->[2] >= $opt->{length} } @{$data};

    for my $info_ref ( @{$data} ) {
        for my $i ( 0, 1 ) {
            $info_ref->[$i]{name} = $i == 0 ? $opt->{tname} : $opt->{qname};
            printf {$out_fh} ">%s\n",
                App::Fasops::encode_header( $info_ref->[$i] );
            printf {$out_fh} "%s\n", $info_ref->[$i]{seq};
        }
        print {$out_fh} "\n";
    }

    close $out_fh;
}

1;
