package App::Fasops::Command::links;

use App::Fasops -command;
use App::RL::Common;
use App::Fasops::Common qw(:all);

use constant abstract => 'scan blocked fasta files and output links between pieces';

sub opt_spec {
    return ( [ "outfile|o=s", "Output filename. [stdout] for screen." ], );
}

sub usage_desc {
    my $self = shift;
    my $desc = $self->SUPER::usage_desc;    # "%c COMMAND %o"
    $desc .= " <infiles>";
    return $desc;
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= "\t<infiles> are paths to blocked fasta files, .fas.gz is supported.\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error("This command need one or more input files.") unless @{$args};
    for ( @{$args} ) {
        if ( !Path::Tiny::path($_)->is_file ) {
            $self->usage_error("The input file [$_] doesn't exist.");
        }
    }

    if ( !exists $opt->{outfile} ) {
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".tsv";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    my @links;
    for my $infile ( @{$args} ) {
        my $in_fh = IO::Zlib->new( $infile, "rb" );

        my $content = '';    # content of one block
        while (1) {
            last if $in_fh->eof and $content eq '';
            my $line = '';
            if ( !$in_fh->eof ) {
                $line = $in_fh->getline;
            }
            next if substr( $line, 0, 1 ) eq "#";

            if ( ( $line eq '' or $line =~ /^\s+$/ ) and $content ne '' ) {
                my $info_of = parse_block($content);
                $content = '';

                my @names = keys %{$info_of};

                for ( my $i = 0; $i <= $#names; $i++ ) {
                    for ( my $j = $i + 1; $j <= $#names; $j++ ) {
                        my $header1 = App::RL::Common::encode_header( $info_of->{ $names[$i] }, 1 );
                        my $header2 = App::RL::Common::encode_header( $info_of->{ $names[$j] }, 1 );
                        push @links, [ $header1, $header2 ];
                    }
                }
            }
            else {
                $content .= $line;
            }
        }

        $in_fh->close;
    }

    my $out_fh;
    if ( lc( $opt->{outfile} ) eq "stdout" ) {
        $out_fh = *STDOUT;
    }
    else {
        open $out_fh, ">", $opt->{outfile};
    }

    for my $link (@links) {
        printf {$out_fh} "%s\t%s\n", $link->[0], $link->[1];
    }
    close $out_fh;
}

1;
