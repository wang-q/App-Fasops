package App::Fasops::Command::replace;

use App::Fasops -command;
use App::Fasops::Common qw(:all);

use constant abstract => 'replace headers from a blocked fasta';

sub opt_spec {
    return ( [ "outfile|o=s", "Output filename. [stdout] for screen." ], );
}

sub usage_desc {
    my $self = shift;
    my $desc = $self->SUPER::usage_desc;    # "%c COMMAND %o"
    $desc .= " <infile> <replace.tsv>";
    return $desc;
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= "\t<infile> is the path to blocked fasta file, .fas.gz is supported.\n";
    $desc .= "\t<replace.tsv> is a tab-separated file containing at least two columns.\n";
    $desc .= "\t\toriginal_name\treplace_name\tmore_replace_name\n";
    $desc .= "\t\tWith three or more fields will duplicate the whole alignment block.\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error("This command need two input files.") unless @{$args} == 2;
    for ( @{$args} ) {
        if ( !Path::Tiny::path($_)->is_file ) {
            $self->usage_error("The input file [$_] doesn't exist.");
        }
    }

    if ( !exists $opt->{outfile} ) {
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".fas";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $replace = read_replaces( $args->[1] );

    #print "$_\n" for keys %{$replace};

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
                my $info_of = parse_block_header($content);
                $content = '';

                my @ori_names = keys %{$info_of};

                my @replace_names = grep { exists $info_of->{$_} } keys %{$replace};

                if ( @replace_names == 0 ) {    # block untouched
                    for my $header (@ori_names) {
                        printf {$out_fh} ">%s\n", encode_header( $info_of->{$header} );
                        printf {$out_fh} "%s\n",  $info_of->{$header}{seq};
                    }
                    print {$out_fh} "\n";
                }
                elsif ( @replace_names == 1 ) {    # each replaces create a new block
                    my $ori_name = $replace_names[0];
                    for my $new_name ( @{ $replace->{$ori_name} } ) {
                        for my $header (@ori_names) {
                            if ( $header eq $ori_name ) {
                                printf {$out_fh} ">%s\n", $new_name;
                                printf {$out_fh} "%s\n",  $info_of->{$header}{seq};
                            }
                            else {
                                printf {$out_fh} ">%s\n", encode_header( $info_of->{$header} );
                                printf {$out_fh} "%s\n",  $info_of->{$header}{seq};
                            }
                        }
                        print {$out_fh} "\n";
                    }
                }
                else {
                    Carp::carp "Don't support multiply records in one block. @replace_names\n";
                    for my $header (@ori_names) {
                        printf {$out_fh} ">%s\n", encode_header( $info_of->{$header} );
                        printf {$out_fh} "%s\n",  $info_of->{$header}{seq};
                    }
                    print {$out_fh} "\n";
                }

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
