package App::Fasops::Command::split;

use App::Fasops -command;
use App::Fasops::Common qw(:all);

use constant abstract => 'split blocked fasta files to separate per-alignment files';

sub opt_spec {
    return (
        [ "outdir|o=s", "output location" ],
        [ "rm|r",       "if outdir exists, remove it before operating" ],
    );
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

    if ( !exists $opt->{outdir} ) {
        $opt->{outdir} = Path::Tiny::path( $args->[0] )->absolute . ".split";
    }
    if ( -e $opt->{outdir} ) {
        if ( $opt->{rm} ) {
            Path::Tiny::path( $opt->{outdir} )->remove_tree;
        }
        else {
            $self->usage_error(
                "Output directory [@{[$opt->{outdir}]}] exists, you should remove it first or add --rm option to avoid errors."
            );
        }
    }

    Path::Tiny::path( $opt->{outdir} )->mkpath;
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    for my $infile ( @{$args} ) {
        my $in_fh = IO::Zlib->new( $args->[0], "rb" );

        my $content = '';    # content of one block
        while (1) {
            last if $in_fh->eof and $content eq '';
            my $line = '';
            if ( !$in_fh->eof ) {
                $line = $in_fh->getline;
            }
            if ( ( $line eq '' or $line =~ /^\s+$/ ) and $content ne '' ) {
                my $info_of = parse_block($content);
                $content = '';

                my $target   = ( keys %{$info_of} )[0];
                my $filename = encode_header( $info_of->{$target} );
                $filename =~ s/\|.+//;    # remove addtional fields
                $filename =~ s/[\(\)\:]+/./g;
                $filename .= '.fas';
                $filename = Path::Tiny::path( $opt->{outdir}, $filename );

                open my $out_fh, ">", $filename;
                for my $key ( keys %{$info_of} ) {
                    print {$out_fh} ">" . $info_of->{$key}{name} . "\n";
                    print {$out_fh} $info_of->{$key}{seq} . "\n";
                }
                close $out_fh;
            }
            else {
                $content .= $line;
            }
        }

        $in_fh->close;
    }
}

1;
