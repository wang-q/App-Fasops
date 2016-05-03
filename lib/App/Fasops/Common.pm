package App::Fasops::Common;
use strict;
use warnings;
use autodie;

use 5.010000;

use AlignDB::IntSpan;
use Carp;
use IO::Zlib;
use IPC::Cmd;
use List::MoreUtils;
use Path::Tiny;
use Tie::IxHash;
use YAML::Syck;

use base 'Exporter';
use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
@ISA         = qw(Exporter);
%EXPORT_TAGS = (
    all => [
        qw{
            read_sizes read_names read_replaces decode_header encode_header parse_block
            parse_block_header parse_axt_block parse_maf_block revcom seq_length align_seqs
            },
    ],
);
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

sub read_sizes {
    my $file       = shift;
    my $remove_chr = shift;

    tie my %length_of, "Tie::IxHash";
    my @lines = path($file)->lines( { chomp => 1 } );
    for (@lines) {
        my ( $key, $value ) = split /\t/;
        $key =~ s/chr0?// if $remove_chr;
        $length_of{$key} = $value;
    }

    return \%length_of;
}

sub read_names {
    my $file = shift;

    my @lines = path($file)->lines( { chomp => 1 } );

    return \@lines;
}

sub read_replaces {
    my $file = shift;

    tie my %replace, "Tie::IxHash";
    my @lines = path($file)->lines( { chomp => 1 } );
    for (@lines) {
        my @fields = split /\t/;
        if ( @fields >= 1 ) {
            my $ori = shift @fields;
            $replace{$ori} = [@fields];
        }
    }

    return \%replace;
}

sub decode_header {
    my $header = shift;

    # S288C.chrI(+):27070-29557|species=S288C
    my $head_qr = qr{
        (?:(?P<name>[\w_]+)\.)?
        (?P<chr_name>[\w-]+)
        (?:\((?P<chr_strand>.+)\))?
        [\:]                        # spacer
        (?P<chr_start>\d+)
        [\_\-]                      # spacer
        (?P<chr_end>\d+)
    }xi;

    tie my %info, "Tie::IxHash";

    $header =~ $head_qr;
    my $name     = $1;
    my $chr_name = $2;

    if ( defined $name or defined $chr_name ) {
        %info = (
            name       => $name,
            chr_name   => $chr_name,
            chr_strand => $3,
            chr_start  => $4,
            chr_end    => $5,
        );
        if ( !defined $info{chr_strand} ) {
            $info{chr_strand} = '+';
        }
        elsif ( $info{chr_strand} eq '1' ) {
            $info{chr_strand} = '+';
        }
        elsif ( $info{chr_strand} eq '-1' ) {
            $info{chr_strand} = '-';
        }
    }
    else {
        $name = $header;
        %info = (
            name       => $name,
            chr_name   => undef,
            chr_strand => undef,
            chr_start  => undef,
            chr_end    => undef,
        );
    }

    # additional keys
    if ( $header =~ /\|(.+)/ ) {
        my @parts = grep {defined} split /;/, $1;
        for my $part (@parts) {
            my ( $key, $value ) = split /=/, $part;
            if ( defined $key and defined $value ) {
                $info{$key} = $value;
            }
        }
    }

    return \%info;
}

sub encode_header {
    my $info           = shift;
    my $only_essential = shift;

    my $header;
    $header .= $info->{name};
    if ( defined $info->{chr_name} ) {
        $header .= "." . $info->{chr_name};
    }
    if ( defined $info->{chr_strand} ) {
        $header .= "(" . $info->{chr_strand} . ")";
    }
    if ( defined $info->{chr_start} ) {
        $header .= ":" . $info->{chr_start};
        $header .= "-" . $info->{chr_end};
    }

    # additional keys
    if ( !$only_essential ) {
        my %essential = map { $_ => 1 } qw{name chr_name chr_strand chr_start chr_end seq full_seq};
        my @parts;
        for my $key ( sort keys %{$info} ) {
            if ( !$essential{$key} ) {
                push @parts, $key . "=" . $info->{$key};
            }
        }
        if (@parts) {
            my $additional = join ";", @parts;
            $header .= "|" . $additional;
        }
    }

    return $header;
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

        my $info_ref = decode_header($header);
        $info_ref->{seq} = $seq;
        if ( defined $info_ref->{name} ) {
            $info_of{ $info_ref->{name} } = $info_ref;
        }
        else {
            my $ess_header = encode_header( $info_ref, 1 );
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

        my $info_ref = decode_header($header);
        my $ess_header = encode_header( $info_ref, 1 );
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

    my %info_of = (
        target => {
            name       => "target",
            chr_name   => $first_chr,
            chr_start  => $first_start,
            chr_end    => $first_end,
            chr_strand => "+",
            seq        => $lines[1],
        },
        query => {
            name       => "query",
            chr_name   => $second_chr,
            chr_start  => $second_start,
            chr_end    => $second_end,
            chr_strand => $query_strand,
            seq        => $lines[2],
        },
    );

    return \%info_of;
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
    my @lines = path($filename)->lines;

    my $cur_name;
    for my $line (@lines) {
        if ( $line =~ /^\>[\w:-]+/ ) {
            $line =~ s/\>//;
            chomp $line;
            $cur_name = $line;
            $seq_of{$cur_name} = '';
        }
        elsif ( $line =~ /^[\w-]+/ ) {
            chomp $line;
            $seq_of{$cur_name} .= $line;
        }
        else {    # Blank line, do nothing
        }
    }

    return \%seq_of;
}

1;
