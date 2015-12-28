package App::Fasops::Common;
use strict;
use warnings;
use autodie;

use 5.008001;

use AlignDB::IntSpan;
use Carp;
use IO::Zlib;
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
            parse_block_header parse_axt_block parse_maf_block revcom
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
        if ( @fields >= 2 ) {
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
            name       => undef,
            chr_name   => 'chrUn',
            chr_strand => '+',
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
    if ( defined $info->{name} ) {
        $header .= $info->{name} . ".";
    }
    $header .= $info->{chr_name};
    if ( defined $info->{chr_strand} ) {
        $header .= "(" . $info->{chr_strand} . ")";
    }
    $header .= ":" . $info->{chr_start};
    $header .= "-" . $info->{chr_end};

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
    my $block = shift;

    my @lines = grep {/\S/} split /\n/, $block;
    Carp::croak "A block of axt should contain three lines\n" if @lines != 3;

    my ($align_serial, $first_chr,  $first_start,  $first_end, $second_chr,
        $second_start, $second_end, $query_strand, $align_score,
    ) = split /\s+/, $lines[0];

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

1;
