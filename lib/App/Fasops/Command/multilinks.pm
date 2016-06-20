package App::Fasops::Command::multilinks;
use strict;
use warnings;
use autodie;

use App::Fasops -command;
use App::RL::Common;
use App::Fasops::Common;

use constant abstract =>
    'scan blocked fasta files and output multilateral range links';

sub opt_spec {
    return ( [ "outfile|o=s", "Output filename. [stdout] for screen." ], );
}

sub usage_desc {
    return "fasops multilinks [options] <infile> [more infiles]";
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc
        .= "\tinfiles are paths to blocked fasta files, .fas.gz is supported.\n";
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
        $opt->{outfile}
            = Path::Tiny::path( $args->[0] )->absolute . ".headers.tsv";
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
                my $info_of = App::Fasops::Common::parse_block( $content, 1 );
                $content = '';

                my @headers = keys %{$info_of};
                push @links, \@headers;
            }
            else {
                $content .= $line;
            }
        }

        $in_fh->close;
    }

    my $out_fh;
    if ( lc( $opt->{outfile} ) eq "stdout" ) {
        $out_fh = \*STDOUT;
    }
    else {
        open $out_fh, ">", $opt->{outfile};
    }

    for my $link (@links) {
        printf {$out_fh} join( "\t", @{$link} );
        printf {$out_fh} "\n";
    }
    close $out_fh;
}

1;
