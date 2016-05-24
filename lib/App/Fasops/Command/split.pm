package App::Fasops::Command::split;
use strict;
use warnings;
use autodie;

use App::Fasops -command;
use App::RL::Common;
use App::Fasops::Common;

use constant abstract =>
    'split blocked fasta files to separate per-alignment files';

sub opt_spec {
    return (
        [ "outdir|o=s", "Output location, [stdout] for screen" ],
        [ "rm|r",       "If outdir exists, remove it before operating." ],
        [ "chr",        "Split by chromosomes." ],
    );
}

sub usage_desc {
    my $self = shift;
    my $desc = $self->SUPER::usage_desc;    # "%c COMMAND %o"
    $desc .= " <infile> [more infiles]";
    return $desc;
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc
        .= "\t<infiles> are paths to blocked fasta files, .fas.gz is supported.\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    if ( !@{$args} ) {
        $self->usage_error("This command need one or more input files.");
    }
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
    }

    if ( lc( $opt->{outdir} ) ne "stdout" ) {
        Path::Tiny::path( $opt->{outdir} )->mkpath;
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    for my $infile ( @{$args} ) {
        my $in_fh = IO::Zlib->new( $infile, "rb" );

        my $content = '';    # content of one block
        while (1) {
            last if $in_fh->eof and $content eq '';
            my $line = '';
            if ( !$in_fh->eof ) {
                $line = $in_fh->getline;
            }
            if ( ( $line eq '' or $line =~ /^\s+$/ ) and $content ne '' ) {
                my $info_of = App::Fasops::Common::parse_block($content);
                $content = '';

                if ( lc( $opt->{outdir} ) eq "stdout" ) {
                    for my $key ( keys %{$info_of} ) {
                        printf ">%s\n",
                            App::RL::Common::encode_header( $info_of->{$key} );
                        print $info_of->{$key}{seq} . "\n";
                    }
                }
                else {
                    my $target = ( keys %{$info_of} )[0];
                    my $filename;
                    if ( $opt->{chr} ) {
                        $filename = $info_of->{$target}{chr_name};
                        $filename .= '.fas';
                    }
                    else {
                        $filename = App::RL::Common::encode_header(
                            $info_of->{$target} );
                        $filename =~ s/\|.+//;    # remove addtional fields
                        $filename =~ s/[\(\)\:]+/./g;
                        $filename .= '.fas';
                    }
                    $filename = Path::Tiny::path( $opt->{outdir}, $filename );

                    open my $out_fh, ">>", $filename;
                    for my $key ( keys %{$info_of} ) {
                        printf {$out_fh} ">%s\n",
                            App::RL::Common::encode_header( $info_of->{$key} );
                        print {$out_fh} $info_of->{$key}{seq} . "\n";
                    }
                    print {$out_fh} "\n";
                    close $out_fh;
                }
            }
            else {
                $content .= $line;
            }
        }

        $in_fh->close;
    }
}

1;
