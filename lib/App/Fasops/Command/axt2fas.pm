package App::Fasops::Command::axt2fas;
use strict;
use warnings;
use autodie;

use App::Fasops -command;
use App::RL::Common;
use App::Fasops::Common;

use constant abstract => 'convert axt to blocked fasta';

sub opt_spec {
    return (
        [ "outfile|o=s", "Output filename, [stdout] for screen." ],
        [ "length|l=i", "the threshold of alignment length, default is [1]", { default => 1 } ],
        [ "tname|t=s", "target name, default is [target]", { default => "target" } ],
        [ "qname|q=s", "query name, default is [query]",   { default => "query" } ],
        [   "size|s=s",
            "query chr.sizes. Without this file, positions of negtive strand of query will be wrong",
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
    $desc .= "Convert UCSC axt pairwise alignment file to blocked fasta file.\n";
    $desc .= "\t<infiles> are paths to axt files, .axt.gz is supported\n";
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
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".fas";
    }

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

    if ( $opt->{size} ) {
        if ( !Path::Tiny::path( $opt->{size} )->is_file ) {
            $self->usage_error("The size file [$opt->{size}] doesn't exist.");
        }
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $out_fh;
    if ( lc( $opt->{outfile} ) eq "stdout" ) {
        $out_fh = *STDOUT;
    }
    else {
        open $out_fh, ">", $opt->{outfile};
    }

    my $length_of;
    if ( $opt->{size} ) {
        $length_of = App::RL::Common::read_sizes( $opt->{size} );
    }

    for my $infile ( @{$args} ) {
        my $in_fh = IO::Zlib->new( $infile, "rb" );

        my $content = '';    # content of one block
        while (1) {
            last if $in_fh->eof and $content eq '';
            my $line = '';
            if ( !$in_fh->eof ) {
                $line = $in_fh->getline;
            }

            if ( substr( $line, 0, 1 ) eq "#" ) {
                next;
            }
            elsif ( ( $line eq '' or $line =~ /^\s+$/ ) and $content ne '' ) {
                my $info_of = App::Fasops::Common::parse_axt_block( $content, $length_of );
                $content = '';

                next if App::Fasops::Common::seq_length( $info_of->{target}{seq} ) < $opt->{length};
                next if App::Fasops::Common::seq_length( $info_of->{query}{seq} ) < $opt->{length};

                $info_of->{target}{name} = $opt->{tname};
                $info_of->{query}{name}  = $opt->{qname};

                for my $key (qw{target query}) {
                    my $info = $info_of->{$key};
                    printf {$out_fh} ">%s\n", App::RL::Common::encode_header($info);
                    printf {$out_fh} "%s\n",  $info->{seq};
                }
                print {$out_fh} "\n";
            }
            else {
                $content .= $line;
            }
        }

        $in_fh->close;
    }

    close $out_fh;
}

1;
