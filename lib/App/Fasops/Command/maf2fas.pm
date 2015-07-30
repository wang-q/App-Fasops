package App::Fasops::Command::maf2fas;

use App::Fasops -command;

use constant abstract => 'convert maf to blocked fasta';

sub opt_spec {
    return (
        [ "outfile|o=s", "output filename" ],
        [   "length|l=i",
            "the threshold of alignment length, default is [1]",
            { default => 1 }
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
        .= "Convert UCSC maf multiply alignment file to blocked fasta file.\n";
    $desc .= "\t<infile> is the path to maf file, .maf.gz is supported\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error("This command need a input file.") unless @$args;
    $self->usage_error("The input file [@{[$args->[0]]}] doesn't exist.")
        unless -e $args->[0];

    if ( !exists $opt->{outfile} ) {
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".fas";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $in_fh = IO::Zlib->new( $args->[0], "rb" );
    open my $out_fh, ">", $opt->{outfile};

    # read and write
    my $content = '';
ALN: while ( my $line = <$in_fh> ) {
        if ( $line =~ /^\s+$/ and $content =~ /\S/ ) {    # meet blank line
            my @slines = grep {/\S/} split /\n/, $content;
            $content = '';

            # parse maf
            my @names;
            my $info_of = {};
            for my $sline (@slines) {
                my ( $s, $src, $start, $size, $strand, $srcsize, $text )
                    = split /\s+/, $sline;

                my ( $species, $chr_name ) = split /\./, $src;
                $chr_name = $species if !defined $chr_name;

                # adjust coordinates to be one-based inclusive
                $start = $start + 1;

                push @names, $species;
                $info_of->{$species} = {
                    seq        => $text,
                    name       => $species,
                    chr_name   => $chr_name,
                    chr_start  => $start,
                    chr_end    => $start + $size - 1,
                    chr_strand => $strand,
                };
            }

            # output
            for my $species (@names) {
                printf {$out_fh} ">%s\n",
                    App::Fasops::encode_header( $info_of->{$species} );
                printf {$out_fh} "%s\n", $info_of->{$species}{seq};
            }
            print {$out_fh} "\n";
        }
        elsif ( $line =~ /^#/ ) {    # comments
            next;
        }
        elsif ( $line =~ /^s\s/ ) {    # s line, contain info and seq
            $content .= $line;
        }
        else {                         # a, i, e, q lines
                # just ommit it
                # see http://genome.ucsc.edu/FAQ/FAQformat.html#format5
        }
    }

    $in_fh->close;
    close $out_fh;
}

1;
