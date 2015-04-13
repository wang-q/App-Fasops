use strict;
use warnings;
use autodie;

package App::Fasops;

# ABSTRACT: operating blocked fasta files

use App::Cmd::Setup -app;
use File::Spec;
use File::Basename;
use IO::Zlib;
use File::Remove qw(remove);

=head1 SYNOPSIS

See C<fasops commands> for usage information.

=cut

sub decode_header {
    my $header = shift;

    # S288C.chrI(+):27070-29557|species=S288C
    my $head_qr = qr{
                ([\w_]+)?           # name
                [\.]?               # spacer
                ((?:chr)?[\w-]+)    # chr name
                (?:\((.+)\))?       # strand
                [\:]                # spacer
                (\d+)               # chr start
                [\_\-]              # spacer
                (\d+)               # chr end
            }xi;

    my $info = {};

    $header =~ $head_qr;
    my $name     = $1;
    my $chr_name = $2;

    if ( defined $name ) {
        $info = {
            chr_name   => $2,
            chr_strand => $3,
            chr_start  => $4,
            chr_end    => $5,
        };
        if ( $info->{chr_strand} eq '1' ) {
            $info->{chr_strand} = '+';
        }
        elsif ( $info->{chr_strand} eq '-1' ) {
            $info->{chr_strand} = '-';
        }
    }
    elsif ( defined $chr_name ) {
        $name = $header;
        $info = {
            chr_name   => $2,
            chr_strand => $3,
            chr_start  => $4,
            chr_end    => $5,
        };
        if ( !defined $info->{chr_strand} ) {
            $info->{chr_strand} = '+';
        }
        elsif ( $info->{chr_strand} eq '1' ) {
            $info->{chr_strand} = '+';
        }
        elsif ( $info->{chr_strand} eq '-1' ) {
            $info->{chr_strand} = '-';
        }
    }
    else {
        $name = $header;
        $info = {
            chr_name   => 'chrUn',
            chr_strand => '+',
            chr_start  => undef,
            chr_end    => undef,
        };
    }
    $info->{name} = $name;

    # additional keys
    if ( $header =~ /\|(.+)/ ) {
        my @parts = grep {defined} split /;/, $1;
        for my $part (@parts) {
            my ( $key, $value ) = split /=/, $part;
            if ( defined $key and defined $value ) {
                $info->{$key} = $value;
            }
        }
    }

    return $info;
}

sub encode_header {
    my $info = shift;

    my $header;
    $header .= $info->{name};
    $header .= "." . $info->{chr_name};
    $header .= "(" . $info->{chr_strand} . ")";
    $header .= ":" . $info->{chr_start};
    $header .= "-" . $info->{chr_end};

    # additional keys
    my %essential = map { $_ => 1 }
        qw{name chr_name chr_strand chr_start chr_end seq full_seq};
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

    return $header;
}

sub write_fasta {
    my $filename   = shift;
    my $seq_of     = shift;
    my $seq_names  = shift;
    my $real_names = shift;

    open my $fh, ">", $filename;
    for my $i ( 0 .. @{$seq_names} - 1 ) {
        my $seq = $seq_of->{ $seq_names->[$i] };
        my $header;
        if ($real_names) {
            $header = $real_names->[$i];
        }
        else {
            $header = $seq_names->[$i];
        }

        print {$fh} ">" . $header . "\n";
        print {$fh} $seq . "\n";
    }
    close $fh;

    return;
}

1;

#----------------------------------------------------------#
# split
#----------------------------------------------------------#
package App::Fasops::Command::split;

use App::Fasops -command;

use constant abstract =>
    'split a blocked fasta file to seperate per-alignment files';

sub opt_spec {
    return (
        [ "outdir|o=s", "output location" ],
        [ "rm|r",       "if outdir exists, remove it before operating" ],
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
    $desc .= "Split a blocked fasta file to seperate per-alignment files.\n";
    $desc
        .= "\t<infile> is the path to blocked fasta file, .fas.gz is supported.\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error("This command need a input file.") unless @$args;
    $self->usage_error("The input file [@{[$args->[0]]}] doesn't exist.")
        unless -e $args->[0];

    if ( !exists $opt->{outdir} ) {
        $opt->{outdir} = File::Spec->rel2abs( $args->[0] ) . ".split";
    }
    if ( -e $opt->{outdir} ) {
        if ( $opt->{rm} ) {
            remove( \1, -e $opt->{outdir} );
        }
        else {
            $self->usage_error(
                "Output directory [@{[$opt->{outdir}]}] exists, you should remove it first or add --rm option to avoid errors."
            );
        }
    }

    mkdir $opt->{outdir}, 0777;
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $in_fh = IO::Zlib->new( $args->[0], "rb" );

    {
        my $content = '';
        while ( my $line = <$in_fh> ) {
            if ( $line =~ /^\s+$/ and $content =~ /\S/ ) {
                my @lines = grep {/\S/} split /\n/, $content;
                $content = '';
                die "headers not equal to seqs\n" if @lines % 2;
                die "Two few lines in block\n" if @lines < 4;

                my ( @headers, %seq_of, @simple_names );
                while (@lines) {

                    # header
                    my $header = shift @lines;
                    $header =~ s/^\>//;
                    chomp $header;
                    push @headers, $header;

                    # seq
                    my $seq = shift @lines;
                    chomp $seq;
                    $seq = uc $seq;
                    $seq_of{$header} = $seq;

                    # simple name
                    my $info_ref = App::Fasops::decode_header($header);
                    push @simple_names, $info_ref->{name};
                }

                # build info required by write_fasta()
                my $out_filename = $headers[0];
                $out_filename =~ s/\|.+//;    # remove addtional fields
                $out_filename =~ s/[\(\)\:]+/./g;
                $out_filename .= '.fas';
                my $out_file
                    = File::Spec->catfile( $opt->{outdir}, $out_filename );
                App::Fasops::write_fasta( $out_file, \%seq_of, \@headers,
                    \@simple_names );
            }
            else {
                $content .= $line;
            }
        }
    }

    $in_fh->close;
}

1;

#----------------------------------------------------------#
# axt2fas
#----------------------------------------------------------#
package App::Fasops::Command::axt2fas;

use App::Fasops -command;

use constant abstract => 'convert axt to blocked fasta';

sub opt_spec {
    return (
        [ "outfile|o=s", "output filename" ],
        [   "length|l=i",
            "the threshold of alignment length, default is [1000]",
            { default => 1000 }
        ],
        [   "tname|t=s",
            "target name, default is [target]",
            { default => "target" }
        ],
        [   "qname|q=s",
            "query name, default is [query]",
            { default => "query" }
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
    $desc
        .= "Convert UCSC axt pairwise alignment file to blocked fasta file.\n";
    $desc .= "\t<infile> is the path to axt file, .axt.gz is supported\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error("This command need a input file.") unless @$args;
    $self->usage_error("The input file [@{[$args->[0]]}] doesn't exist.")
        unless -e $args->[0];

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

    if ( !exists $opt->{outfile} ) {
        $opt->{outfile} = File::Spec->rel2abs( $args->[0] ) . ".fas";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    open my $out_fh, ">", $opt->{outfile};

    # read and write
    my $data = parse_axt( $args->[0] );
    @{$data} = grep { $_->[2] >= $opt->{length} } @{$data};

    for my $info_ref ( @{$data} ) {
        for my $i ( 0, 1 ) {
            $info_ref->[$i]{name} = $i == 0 ? $opt->{tname} : $opt->{qname};
            printf {$out_fh} ">%s\n",
                App::Fasops::encode_header( $info_ref->[$i] );
            printf {$out_fh} "%s\n", $info_ref->[$i]{seq};
        }
        print {$out_fh} "\n";
    }

    close $out_fh;
}

sub parse_axt {
    my $file = shift;

    my $in_fh = IO::Zlib->new( $file, "rb" );

    my @data;
    while (1) {
        my $summary_line = <$in_fh>;
        last unless $summary_line;
        next if $summary_line =~ /^#/;

        chomp $summary_line;
        chomp( my $first_line  = <$in_fh> );
        chomp( my $second_line = <$in_fh> );
        my $dummy = <$in_fh>;    # blank line

        my ($align_serial, $first_chr,    $first_start,
            $first_end,    $second_chr,   $second_start,
            $second_end,   $query_strand, $align_score,
        ) = split /\s+/, $summary_line;

        my $info_refs = [
            {   chr_name   => $first_chr,
                chr_start  => $first_start,
                chr_end    => $first_end,
                chr_strand => '+',
                seq        => $first_line,
            },
            {   chr_name   => $second_chr,
                chr_start  => $second_start,
                chr_end    => $second_end,
                chr_strand => $query_strand,
                seq        => $second_line,
            },
            length $first_line,
        ];

        push @data, $info_refs;
    }

    $in_fh->close;

    return \@data;
}

1;
