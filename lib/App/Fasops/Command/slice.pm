package App::Fasops::Command::slice;
use strict;
use warnings;
use autodie;

use App::Fasops -command;
use App::RL::Common;
use App::Fasops::Common;

use constant abstract => 'extract alignment slices from a blocked fasta';

sub opt_spec {
    return (
        [ "outfile|o=s", "Output filename. [stdout] for screen." ],
        [ "name=s",      "According to this species. Default is the first one." ],
    );
}

sub usage_desc {
    my $self = shift;
    my $desc = $self->SUPER::usage_desc;    # "%c COMMAND %o"
    $desc .= " <infile> <runlist.yml>";
    return $desc;
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= "\t<infile> is the path to blocked fasta file, .fas.gz is supported.\n";
    $desc .= "\t<runlist.yml> is a App::RL dump.\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error("This command need two input files.") unless @$args == 2;
    for ( @{$args} ) {
        if ( !Path::Tiny::path($_)->is_file ) {
            $self->usage_error("The input file [$_] doesn't exist.");
        }
    }

    if ( !exists $opt->{outfile} ) {
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".slice.fas";
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

    my $set_single = App::RL::Common::runlist2set( YAML::Syck::LoadFile( $args->[1] ) );

    {
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

                # set $opt->{name} to the first one of the first block
                if ( !defined $opt->{name} ) {
                    ( $opt->{name} ) = keys %{$info_of};
                }

                # target name
                my $name = $opt->{name};

                # basic target information
                my $chr_name   = $info_of->{$name}{chr_name};
                my $chr_strand = $info_of->{$name}{chr_strand};
                my $chr_start  = $info_of->{$name}{chr_start};
                my $chr_end    = $info_of->{$name}{chr_end};

                # chr present
                next unless exists $set_single->{$chr_name};
                next if $set_single->{$chr_name}->is_empty;

                # has intersect
                my $i_chr_intspan;
                {
                    my AlignDB::IntSpan $slice_set = $set_single->{$chr_name};
                    my $align_chr_set = AlignDB::IntSpan->new;
                    $align_chr_set->add_pair( $chr_start, $chr_end );
                    $i_chr_intspan = $slice_set->intersect($align_chr_set);
                }
                next if $i_chr_intspan->is_empty;

                #                print YAML::Syck::Dump {
                #                    name          => $name,
                #                    chr_name      => $chr_name,
                #                    chr_strand    => $chr_strand,
                #                    chr_start     => $chr_start,
                #                    chr_end       => $chr_end,
                #                    i_chr_intspan => $i_chr_intspan->runlist,
                #                };

                # all indel regions
                my $indel_intspan = AlignDB::IntSpan->new;
                for my $key ( keys %{$info_of} ) {
                    $indel_intspan->add(
                        App::Fasops::Common::indel_intspan( $info_of->{$key}{seq} ) );
                }

                # sequence set
                my $seq_intspan = App::Fasops::Common::seq_intspan( $info_of->{$name}{seq} );

                # there may be more than one subslice intersect this alignment
                my @sub_slices;
                for my AlignDB::IntSpan $ss_chr_intspan ( $i_chr_intspan->sets ) {

                    # chr positions to align positions
                    my $ss_start
                        = App::Fasops::Common::chr_to_align( $seq_intspan, $ss_chr_intspan->min,
                        $chr_start, $chr_strand );
                    my $ss_end
                        = App::Fasops::Common::chr_to_align( $seq_intspan, $ss_chr_intspan->max,
                        $chr_start, $chr_strand );
                    next if $ss_start >= $ss_end;

                    my $ss_intspan = AlignDB::IntSpan->new;
                    $ss_intspan->add_pair( $ss_start, $ss_end );

                    # borders of subslice inside a indel
                    if ( $indel_intspan->contains($ss_start) ) {
                        my $indel_island = $indel_intspan->find_islands($ss_start);
                        $ss_intspan->remove($indel_island);
                    }
                    if ( $indel_intspan->contains($ss_end) ) {
                        my $indel_island = $indel_intspan->find_islands($ss_end);
                        $ss_intspan->remove($indel_island);
                    }
                    next if $ss_intspan->size <= 1;
                    push @sub_slices, $ss_intspan;
                }

                # write heasers and sequences
                for my AlignDB::IntSpan $sub_slice (@sub_slices) {
                    my $ss_start = $sub_slice->min;
                    my $ss_end   = $sub_slice->max;

                    for my $key ( keys %{$info_of} ) {
                        my $key_start = App::Fasops::Common::align_to_chr(
                            $seq_intspan, $ss_start,
                            $info_of->{$key}{chr_start},
                            $info_of->{$key}{chr_strand}
                        );
                        my $key_end = App::Fasops::Common::align_to_chr(
                            $seq_intspan, $ss_end,
                            $info_of->{$key}{chr_start},
                            $info_of->{$key}{chr_strand}
                        );
                        my $ss_info = {
                            name       => $info_of->{$key}{name},
                            chr_name   => $info_of->{$key}{chr_name},
                            chr_strand => $info_of->{$key}{chr_strand},
                            chr_start  => $key_start,
                            chr_end    => $key_end,
                        };
                        printf {$out_fh} ">%s\n", App::RL::Common::encode_header($ss_info);
                        printf {$out_fh} "%s\n",
                            substr( $info_of->{$key}{seq}, $ss_start - 1, $ss_end - $ss_start + 1 );
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
