package App::Fasops::Common;
use strict;
use warnings;
use autodie;

use 5.010000;

use Carp;
use IO::Zlib;
use IPC::Cmd;
use List::Util;
use List::MoreUtils::PP;
use Path::Tiny;
use Tie::IxHash;
use YAML::Syck;

use AlignDB::IntSpan;
use App::RL::Common;

sub read_replaces {
    my $file = shift;

    tie my %replace, "Tie::IxHash";
    my @lines = Path::Tiny::path($file)->lines( { chomp => 1 } );
    for (@lines) {
        my @fields = split /\t/;
        if ( @fields >= 1 ) {
            my $ori = shift @fields;
            $replace{$ori} = [@fields];
        }
    }

    return \%replace;
}

sub parse_block {
    my $block = shift;

    my @lines = grep {/\S/} split /\n/, $block;
    Carp::croak "Numbers of headers not equal to seqs\n" if @lines % 2;

    tie my %info_of, "Tie::IxHash";
    while (@lines) {
        my $header = shift @lines;
        $header =~ s/^\>//;
        chomp $header;

        my $seq = shift @lines;
        chomp $seq;

        my $info_ref = App::RL::Common::decode_header($header);
        $info_ref->{seq} = $seq;
        if ( defined $info_ref->{name} ) {
            $info_of{ $info_ref->{name} } = $info_ref;
        }
        else {
            my $ess_header = App::RL::Common::encode_header( $info_ref, 1 );
            $info_of{$ess_header} = $info_ref;
        }
    }

    return \%info_of;
}

sub parse_block_header {
    my $block = shift;

    my @lines = grep {/\S/} split /\n/, $block;
    Carp::croak "Numbers of headers not equal to seqs\n" if @lines % 2;

    tie my %info_of, "Tie::IxHash";
    while (@lines) {
        my $header = shift @lines;
        $header =~ s/^\>//;
        chomp $header;

        my $seq = shift @lines;
        chomp $seq;

        my $info_ref = App::RL::Common::decode_header($header);
        my $ess_header = App::RL::Common::encode_header( $info_ref, 1 );
        $info_ref->{seq} = $seq;
        $info_of{$ess_header} = $info_ref;
    }

    return \%info_of;
}

sub parse_axt_block {
    my $block     = shift;
    my $length_of = shift;

    my @lines = grep {/\S/} split /\n/, $block;
    Carp::croak "A block of axt should contain three lines\n" if @lines != 3;

    my ($align_serial, $first_chr,  $first_start,  $first_end, $second_chr,
        $second_start, $second_end, $query_strand, $align_score,
    ) = split /\s+/, $lines[0];

    if ( $query_strand eq "-" ) {
        if ( defined $length_of and ref $length_of eq "HASH" ) {
            if ( exists $length_of->{$second_chr} ) {
                $second_start = $length_of->{$second_chr} - $second_start + 1;
                $second_end   = $length_of->{$second_chr} - $second_end + 1;
                ( $second_start, $second_end ) = ( $second_end, $second_start );
            }
        }
    }

    my $info_refs = [
        {   name       => "target",
            chr_name   => $first_chr,
            chr_start  => $first_start,
            chr_end    => $first_end,
            chr_strand => "+",
            seq        => $lines[1],
        },
        {   name       => "query",
            chr_name   => $second_chr,
            chr_start  => $second_start,
            chr_end    => $second_end,
            chr_strand => $query_strand,
            seq        => $lines[2],
        },
    ];

    return $info_refs;
}

sub parse_maf_block {
    my $block = shift;

    my @lines = grep {/\S/} split /\n/, $block;
    Carp::croak "A block of maf should contain s lines\n" unless @lines > 0;

    tie my %info_of, "Tie::IxHash";

    for my $sline (@lines) {
        my ( $s, $src, $start, $size, $strand, $srcsize, $text ) = split /\s+/, $sline;

        my ( $species, $chr_name ) = split /\./, $src;
        $chr_name = $species if !defined $chr_name;

        # adjust coordinates to be one-based inclusive
        $start = $start + 1;

        $info_of{$species} = {
            name       => $species,
            chr_name   => $chr_name,
            chr_start  => $start,
            chr_end    => $start + $size - 1,
            chr_strand => $strand,
            seq        => $text,
        };
    }

    return \%info_of;
}

sub revcom {
    my $seq = shift;

    $seq =~ tr/ACGTMRWSYKVHDBNacgtmrwsykvhdbn-/TGCAKYWSRMBDHVNtgcakyswrmbdhvn-/;
    my $seq_rc = reverse $seq;

    return $seq_rc;
}

sub seq_length {
    my $seq = shift;

    my $gaps = $seq =~ tr/-/-/;

    return length($seq) - $gaps;
}

#@returns AlignDB::IntSpan
sub indel_intspan {
    my $seq = shift;

    my $intspan = AlignDB::IntSpan->new;
    my $length  = length($seq);

    my $offset = 0;
    my $start  = 0;
    my $end    = 0;
    for my $pos ( 1 .. $length ) {
        my $base = substr( $seq, $pos - 1, 1 );
        if ( $base eq '-' ) {
            if ( $offset == 0 ) {
                $start = $pos;
            }
            $offset++;
        }
        else {
            if ( $offset != 0 ) {
                $end = $pos - 1;
                $intspan->add_pair( $start, $end );
            }
            $offset = 0;
        }
    }
    if ( $offset != 0 ) {
        $end = $length;
        $intspan->add_pair( $start, $end );
    }

    return $intspan;
}

sub align_seqs {
    my $seq_refs = shift;
    my $aln_prog = shift;

    # get executable
    my $bin;

    if ( !defined $aln_prog or $aln_prog =~ /clus/i ) {
        $aln_prog = 'clustalw';
        for my $e (qw{clustalw clustal-w clustalw2}) {
            if ( IPC::Cmd::can_run($e) ) {
                $bin = $e;
                last;
            }
        }
    }
    elsif ( $aln_prog =~ /musc/i ) {
        $aln_prog = 'muscle';
        for my $e (qw{muscle}) {
            if ( IPC::Cmd::can_run($e) ) {
                $bin = $e;
                last;
            }
        }
    }
    elsif ( $aln_prog =~ /maff/i ) {
        $aln_prog = 'mafft';
        for my $e (qw{mafft}) {
            if ( IPC::Cmd::can_run($e) ) {
                $bin = $e;
                last;
            }
        }
    }

    if ( !defined $bin ) {
        confess "Could not find the executable for $aln_prog\n";
    }

    # temp in and out
    my $temp_in  = Path::Tiny->tempfile("seq_in_XXXXXXXX");
    my $temp_out = Path::Tiny->tempfile("seq_out_XXXXXXXX");

    # msa may change the order of sequences
    my @indexes = 0 .. scalar( @{$seq_refs} - 1 );
    {
        my $fh = $temp_in->openw;
        for my $i (@indexes) {
            printf {$fh} ">seq_%d\n", $i;
            printf {$fh} "%s\n",      $seq_refs->[$i];
        }
        close $fh;
    }

    my @args;
    if ( $aln_prog eq "clustalw" ) {
        push @args, "-align -type=dna -output=fasta -outorder=input -quiet";
        push @args, "-infile=" . $temp_in->absolute->stringify;
        push @args, "-outfile=" . $temp_out->absolute->stringify;
    }
    elsif ( $aln_prog eq "muscle" ) {
        push @args, "-quiet";
        push @args, "-in " . $temp_in->absolute->stringify;
        push @args, "-out " . $temp_out->absolute->stringify;
    }
    elsif ( $aln_prog eq "mafft" ) {
        push @args, "--quiet";
        push @args, "--auto";
        push @args, $temp_in->absolute->stringify;
        push @args, "> " . $temp_out->absolute->stringify;
    }

    my $cmd_line = join " ", ( $bin, @args );
    my $ok = IPC::Cmd::run( command => $cmd_line );

    if ( !$ok ) {
        Carp::confess("$aln_prog call failed\n");
    }

    my @aligned;
    my $seq_of = read_fasta( $temp_out->absolute->stringify );
    for my $i (@indexes) {
        push @aligned, $seq_of->{ "seq_" . $i };
    }

    # delete .dnd files created by clustalw
    #printf STDERR "%s\n", $temp_in->absolute->stringify;
    if ( $aln_prog eq "clustalw" ) {
        my $dnd = $temp_in->absolute->stringify . ".dnd";
        path($dnd)->remove;
    }

    undef $temp_in;
    undef $temp_out;

    return \@aligned;
}

# read normal fasta files
sub read_fasta {
    my $filename = shift;

    tie my %seq_of, "Tie::IxHash";

    my $in_fh = path($filename)->openr;

    my $cur_name;
    while ( my $line = <$in_fh> ) {
        chomp $line;
        if ( $line =~ /^\>\S+/ ) {
            $line =~ s/\>//;
            $cur_name = $line;
            $seq_of{$cur_name} = '';
        }
        elsif ( $line =~ /^[\w-]+/ ) {
            $seq_of{$cur_name} .= $line;
        }
        else {    # Blank line, do nothing
        }

    }

    close $in_fh;
    return \%seq_of;
}

sub mean {
    @_ = grep { defined $_ } @_;
    return 0 unless @_;
    return $_[0] unless @_ > 1;
    return List::Util::sum(@_) / scalar(@_);
}

sub calc_gc_ratio {
    my $seq_refs = shift;

    my $seq_count = scalar @{$seq_refs};

    my @ratios;
    for my $i ( 0 .. $seq_count - 1 ) {

        # Count all four bases
        my $a_count = $seq_refs->[$i] =~ tr/Aa/Aa/;
        my $g_count = $seq_refs->[$i] =~ tr/Gg/Gg/;
        my $c_count = $seq_refs->[$i] =~ tr/Cc/Cc/;
        my $t_count = $seq_refs->[$i] =~ tr/Tt/Tt/;

        my $four_count = $a_count + $g_count + $c_count + $t_count;
        my $gc_count   = $g_count + $c_count;

        if ( $four_count == 0 ) {
            next;
        }
        else {
            my $gc_ratio = $gc_count / $four_count;
            push @ratios, $gc_ratio;
        }
    }

    return mean(@ratios);
}

sub pair_D {
    my $seq_refs = shift;

    my $seq_count = scalar @{$seq_refs};
    if ( $seq_count != 2 ) {
        Carp::confess "Need two sequences\n";
    }

    my $legnth = length $seq_refs->[0];

    my ( $comparable_bases, $differences ) = (0) x 2;

    for my $pos ( 1 .. $legnth ) {
        my $base0 = substr $seq_refs->[0], $pos - 1, 1;
        my $base1 = substr $seq_refs->[1], $pos - 1, 1;

        if (   $base0 =~ /[atcg]/i
            && $base1 =~ /[atcg]/i )
        {
            $comparable_bases++;
            if ( $base0 ne $base1 ) {
                $differences++;
            }
        }
    }

    if ( $comparable_bases == 0 ) {
        Carp::carp "comparable_bases == 0\n";
        return 0;
    }
    else {
        return $differences / $comparable_bases;
    }
}

# Split D value to D1 (substitutions in first_seq), D2( substitutions in second_seq) and Dcomplex
# (substitutions can't be referred)
sub ref_pair_D {
    my $seq_refs = shift;

    my $seq_count = scalar @{$seq_refs};
    if ( $seq_count != 3 ) {
        Carp::confess "Need three sequences\n";
    }

    my ( $d1, $d2, $dc ) = (0) x 3;
    my $length = length $seq_refs->[0];

    return ( $d1, $d2, $dc ) if $length == 0;

    for my $pos ( 1 .. $length ) {
        my $base0    = substr $seq_refs->[0], $pos - 1, 1;
        my $base1    = substr $seq_refs->[0], $pos - 1, 1;
        my $base_ref = substr $seq_refs->[0], $pos - 1, 1;
        if ( $base0 ne $base1 ) {
            if (   $base0 =~ /[atcg]/i
                && $base1 =~ /[atcg]/i
                && $base_ref =~ /[atcg]/i )
            {
                if ( $base1 eq $base_ref ) {
                    $d1++;
                }
                elsif ( $base0 eq $base_ref ) {
                    $d2++;
                }
                else {
                    $dc++;
                }
            }
            else {
                $dc++;
            }
        }
    }

    for ( $d1, $d2, $dc ) {
        $_ /= $length;
    }

    return ( $d1, $d2, $dc );
}

sub multi_seq_stat {
    my $seq_refs = shift;

    my $seq_count = scalar @{$seq_refs};
    if ( $seq_count < 2 ) {
        Carp::confess "Need two or more sequences\n";
    }

    my $legnth = length $seq_refs->[0];

    # For every positions, search for polymorphism_site
    my ( $comparable_bases, $identities, $differences, $gaps, $ns, $align_errors, ) = (0) x 6;
    for my $pos ( 1 .. $legnth ) {
        my @bases = ();
        for my $i ( 0 .. $seq_count - 1 ) {
            my $base = substr( $seq_refs->[$i], $pos - 1, 1 );
            push @bases, $base;
        }
        @bases = List::MoreUtils::PP::uniq(@bases);

        if ( List::MoreUtils::PP::all { $_ =~ /[agct]/i } @bases ) {
            $comparable_bases++;
            if ( List::MoreUtils::PP::all { $_ eq $bases[0] } @bases ) {
                $identities++;
            }
            else {
                $differences++;
            }
        }
        elsif ( List::MoreUtils::PP::any { $_ eq '-' } @bases ) {
            $gaps++;
        }
        else {
            $ns++;
        }
    }
    if ( $comparable_bases == 0 ) {
        print YAML::Syck::Dump { seqs => $seq_refs, };
        Carp::carp "number_of_comparable_bases == 0!!\n";
        return [ $legnth, $comparable_bases, $identities, $differences, $gaps,
            $ns, $legnth, undef, ];
    }

    my @all_Ds;
    for ( my $i = 0; $i < $seq_count; $i++ ) {
        for ( my $j = $i + 1; $j < $seq_count; $j++ ) {
            my $D = pair_D( [ $seq_refs->[$i], $seq_refs->[$j] ] );
            push @all_Ds, $D;
        }
    }

    my $D = mean(@all_Ds);

    return [ $legnth, $comparable_bases, $identities, $differences, $gaps,
        $ns, $align_errors, $D, ];
}

1;
