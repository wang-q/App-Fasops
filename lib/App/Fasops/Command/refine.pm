package App::Fasops::Command::refine;
use strict;
use warnings;
use autodie;

use App::Fasops -command;
use App::Fasops::Common qw(:all);

use constant abstract => 'realign alignments';

sub opt_spec {
    return (
        [ "outfile|o=s", "Output filename. [stdout] for screen." ],
        [ "msa=s",       "Aligning program ([none] means don't do realigning)." ],
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
    $desc .= ucfirst(abstract) . ".\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error("This command need one input file.") unless @$args;
    $self->usage_error("The input file [@{[$args->[0]]}] doesn't exist.")
        unless -e $args->[0];

    if ( !exists $opt->{outfile} ) {
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".fas";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $in_fh = IO::Zlib->new( $args->[0], "rb" );
    my $out_fh;
    if ( lc( $opt->{outfile} ) eq "stdout" ) {
        $out_fh = *STDOUT;
    }
    else {
        open $out_fh, ">", $opt->{outfile};
    }

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
            
            my @keys = keys %{$info_of};
            my @seqs;
            for my $key (@keys) {
                push @seqs, $info_of->{$key}{seq};
            }
            my $refined = align_seqs( \@seqs );

            for my $i ( 0 .. $#keys ) {
                printf {$out_fh} ">%s\n", encode_header( $info_of->{ $keys[$i] } );
                printf {$out_fh} "%s\n",  $refined->[$i];
            }

            print {$out_fh} "\n";
        }
        else {
            $content .= $line;
        }
    }

    close $out_fh;
    $in_fh->close;
}

1;
