package App::Fasops::Command::refine;
use strict;
use warnings;
use autodie;

use MCE;
use MCE::Flow Sereal => 1;

use App::Fasops -command;
use App::RL::Common;
use App::Fasops::Common;

use constant abstract => 'realign alignments';

sub opt_spec {
    return (
        [ "outfile|o=s", "Output filename. [stdout] for screen." ],
        [ "outgroup",    "Has outgroup at the end of blocks.", ],
        [   "parallel|p=i",
            "run in parallel mode. Default is [1]",
            { default => 1 },
        ],
        [   "msa=s",
            "Aligning program. Default is [clustalw].",
            { default => "mafft" },
        ],
        [   "quick",
            "Quick mode, only aligning indel adjacent regions. Suitable for multiz outputs.",
        ],
        [ "pad=i", "In quick mode, enlarge indel regions", { default => 50 }, ],
        [ "fill=i", "In quick mode, join indel regions", { default => 50 }, ],
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
    $desc .= "List of msa:\n";
    $desc .= " " x 4 . "mafft\n";
    $desc .= " " x 4 . "muscle\n";
    $desc .= " " x 4 . "clustalw\n";
    $desc .= " " x 4 . "none:    means skip realigning\n";

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

    my @infos;    # collect blocks for parallelly refining
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

            if ( $opt->{parallel} >= 2 ) {
                push @infos, $info_of;
            }
            else {
                my $out_string = proc_block( $info_of, $opt );
                print {$out_fh} $out_string;
            }
        }
        else {
            $content .= $line;
        }
    }

    if ( $opt->{parallel} >= 2 ) {
        my $worker = sub {
            my ( $self, $chunk_ref, $chunk_id ) = @_;

            my $info_of = $chunk_ref->[0];
            my $out_string = proc_block( $info_of, $opt );
            MCE->gather($out_string);
        };

        MCE::Flow::init {
            chunk_size  => 1,
            max_workers => $opt->{parallel},
        };
        my @blocks = mce_flow $worker, @infos;
        MCE::Flow::finish;

        for my $block (@blocks) {
            print {$out_fh} $block;
        }
    }

    close $out_fh;
    $in_fh->close;
}

sub proc_block {
    my $info_of = shift;
    my $opt     = shift;

    my @keys     = keys %{$info_of};
    my $seq_refs = [];
    for my $key (@keys) {
        push @{$seq_refs}, $info_of->{$key}{seq};
    }

    #----------------------------#
    # realigning
    #----------------------------#
    if ( $opt->{msa} ne "none" ) {
        if ( $opt->{quick} ) {
            $seq_refs
                = App::Fasops::Common::align_seqs_quick( $seq_refs,
                $opt->{msa}, $opt->{pad}, $opt->{fill} );
        }
        else {
            $seq_refs
                = App::Fasops::Common::align_seqs( $seq_refs, $opt->{msa} );
        }
    }

    #----------------------------#
    # trimming
    #----------------------------#
    App::Fasops::Common::trim_pure_dash($seq_refs);
    if ( $opt->{outgroup} ) {
        App::Fasops::Common::trim_outgroup($seq_refs);
        App::Fasops::Common::trim_complex_indel($seq_refs);
    }

    my $out_string;

    for my $i ( 0 .. $#keys ) {
        $out_string .= sprintf ">%s\n",
            App::RL::Common::encode_header( $info_of->{ $keys[$i] } );
        $out_string .= sprintf "%s\n", uc $seq_refs->[$i];
    }
    $out_string .= "\n";

    return $out_string;
}

1;
