package App::Fasops::Command::maf2fas;
use strict;
use warnings;
use autodie;

use App::Fasops -command;
use App::RL::Common;
use App::Fasops::Common;

use constant abstract => 'convert maf to blocked fasta';

sub opt_spec {
    return (
        [ "outfile|o=s", "Output filename. [stdout] for screen." ],
        [   "length|l=i",
            "the threshold of alignment length, default is [1]",
            { default => 1 }
        ],
    );
}

sub usage_desc {
    return "fasops maf2fas [options] <infile> [more infiles]";
}

sub description {
    my $desc;
    $desc
        .= "Convert UCSC maf multiple alignment file to blocked fasta file.\n";
    $desc .= "\tInfiles are paths to maf files, .maf.gz is supported\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    if ( !@{$args} ) {
        my $message = "This command need one or more input files.\n\tIt found";
        $message .= sprintf " [%s]", $_ for @{$args};
        $message .= ".\n";
        $self->usage_error($message);
    }
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

    my $out_fh;
    if ( lc( $opt->{outfile} ) eq "stdout" ) {
        $out_fh = *STDOUT;
    }
    else {
        open $out_fh, ">", $opt->{outfile};
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

            if ( ( $line eq '' or $line =~ /^\s+$/ ) and $content ne '' ) {
                my $info_of = App::Fasops::Common::parse_maf_block($content);
                $content = '';

                my @names = keys %{$info_of};
                next if length $info_of->{ $names[0] }{seq} < $opt->{length};

                for my $key (@names) {
                    my $info = $info_of->{$key};
                    printf {$out_fh} ">%s\n",
                        App::RL::Common::encode_header($info);
                    printf {$out_fh} "%s\n", $info->{seq};
                }
                print {$out_fh} "\n";
            }
            elsif ( substr( $line, 0, 2 ) eq "s " )
            {    # s line, contain info and seq
                $content .= $line;
            }
            else {
                # omit # lines
                # omit a, i, e, q lines
                # see http://genome.ucsc.edu/FAQ/FAQformat.html#format5
                next;
            }
        }

        $in_fh->close;
    }

    close $out_fh;
}

1;
