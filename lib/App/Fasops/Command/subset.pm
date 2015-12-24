package App::Fasops::Command::subset;

use App::Fasops -command;

use constant abstract => 'extract a subset of species from a blocked fasta';

sub opt_spec {
    return (
        [ "outfile|o=s", "Output filename. [stdout] for screen." ],
        [ "first",       "Always keep the first species." ],
    );
}

sub usage_desc {
    my $self = shift;
    my $desc = $self->SUPER::usage_desc;    # "%c COMMAND %o"
    $desc .= " <infile> <name.list>";
    return $desc;
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= "\t<infile> is the path to blocked fasta file, .fas.gz is supported.\n";
    $desc .= "\t<name.list> is a file with a list of names to keep, one per line.\n";
    $desc .= "\tNames in the output file will following the order in <name.list>.\n";
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

    my @names = @{ App::Fasops::read_names( $args->[1] ) };
    my %seen = map { $_ => 1 } @names;

    my $in_fh = IO::Zlib->new( $args->[0], "rb" );
    my $out_fh;
    if ( lc( $opt->{outfile} ) eq "stdout" ) {
        $out_fh = *STDOUT;
    }
    else {
        open $out_fh, ">", $opt->{outfile};
    }

    {
        my $content = '';    # content of one block
        while (1) {
            last if $in_fh->eof and $content eq '';
            my $line = '';
            if ( !$in_fh->eof ) {
                $line = $in_fh->getline;
            }
            if ( ( $line eq '' or $line =~ /^\s+$/ ) and $content ne '' ) {
                my $info_of = App::Fasops::parse_block($content);
                $content = '';

                my $keep = '';
                if ( $opt->{first} ) {
                    $keep = ( keys %{$info_of} )[0];
                }

                my @block_names = @names;
                if ( $opt->{first} ) {
                    my $first = ( keys %{$info_of} )[0];
                    @block_names = List::MoreUtils::uniq( $first, @block_names );
                }

                for my $name (@block_names) {
                    if ( exists $info_of->{$name} ) {
                        printf {$out_fh} ">%s\n", App::Fasops::encode_header( $info_of->{$name} );
                        printf {$out_fh} "%s\n",  $info_of->{$name}{seq};
                    }
                }
                print {$out_fh} "\n";
            }
            else {
                $content .= $line;
            }
        }
    }
    close $out_fh;
    $in_fh->close;
}

1;
