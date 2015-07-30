use strict;
use warnings;
use autodie;

package App::Fasops;

# ABSTRACT: operating blocked fasta files

use App::Cmd::Setup -app;
use Carp;
use Path::Tiny;
use File::Basename;
use IO::Zlib;
use Tie::IxHash;
use YAML::Syck qw(Dump Load DumpFile LoadFile);

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

    tie my %info, "Tie::IxHash";

    $header =~ $head_qr;
    my $name     = $1;
    my $chr_name = $2;

    if ( defined $name ) {
        %info = (
            chr_name   => $2,
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
    elsif ( defined $chr_name ) {
        $name = $header;
        %info = (
            chr_name   => $2,
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
            chr_name   => 'chrUn',
            chr_strand => '+',
            chr_start  => undef,
            chr_end    => undef,
        );
    }
    $info{name} = $name;

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

sub parse_block {
    my $block = shift;

    my @lines = grep {/\S/} split /\n/, $block;
    croak "headers not equal to seqs\n" if @lines % 2;

    tie my %info_of, "Tie::IxHash";
    while (@lines) {
        my $header = shift @lines;
        $header =~ s/^\>//;
        chomp $header;

        my $seq = shift @lines;
        chomp $seq;

        my $info_ref = App::Fasops::decode_header($header);
        $info_ref->{seq} = $seq;
        $info_of{ $info_ref->{name} } = $info_ref;
    }

    return \%info_of;
}

sub read_sizes {
    my $file       = shift;
    my $remove_chr = shift;

    my @lines = path($file)->lines( { chomp => 1 } );
    my %length_of;
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
        $opt->{outdir} = Path::Tiny::path( $args->[0] )->absolute . ".split";
    }
    if ( -e $opt->{outdir} ) {
        if ( $opt->{rm} ) {
            Path::Tiny::path( $opt->{outdir} )->remove_tree;
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
        my $content = '';    # content of one block
        while (1) {
            last if $in_fh->eof and $content eq '';
            my $line = '';
            if ( !$in_fh->eof ) {
                $line = $in_fh->getline;
            }
            if ( ( $line eq '' or $line =~ /^\s+$/ ) and $content ne '' ) {
                my $info_of = App::Fasops::parse_block($content);
                $content = '';

                my $filename = ( keys %{$info_of} )[0];
                $filename =~ s/\|.+//;    # remove addtional fields
                $filename =~ s/[\(\)\:]+/./g;
                $filename .= '.fas';
                $filename = Path::Tiny::path( $opt->{outdir}, $filename );

                open my $out_fh, ">", $filename;
                for my $key ( keys %{$info_of} ) {
                    print {$out_fh} ">" . $info_of->{$key}{name} . "\n";
                    print {$out_fh} $info_of->{$key}{seq} . "\n";
                }
                close $out_fh;
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
# subset
#----------------------------------------------------------#
package App::Fasops::Command::subset;

use App::Fasops -command;

use constant abstract =>
    'extract a blocked fasta that just has a subset of names';

sub opt_spec {
    return (
        [ "outfile|o=s", "Output filename. [stdout] for screen." ],
        [ "first",       "Always keep the first name." ],
    );
}

sub usage_desc {
    my $self = shift;
    my $desc = $self->SUPER::usage_desc;    # "%c COMMAND %o"
    $desc .= " <infile> <name.list>";
    return $desc;
}

sub description {
    my $desc;
    $desc .= "Extract a blocked fasta that just has a subset of names.\n";
    $desc
        .= "\t<infile> is the path to blocked fasta file, .fas.gz is supported.\n";
    $desc
        .= "\t<name.list> is a file with a list of names to keep, one per line.\n";
    $desc
        .= "\tNames in the output file will following the order in <name.list>.\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error("This command need a input file.") unless @$args;
    $self->usage_error("The input file [@{[$args->[0]]}] doesn't exist.")
        unless -e $args->[0];

    if ( !exists $opt->{outfile} ) {
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".fas";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    my @names = @{ App::Fasops::read_names( $args->[1] ) };
    my %seen = map { $_ => 1 } @names;

    my $in_fh = IO::Zlib->new( $args->[0], "rb" );
    my $out_fh;
    if ( lc( $opt->{outfile} ) eq "stdout" ) {
        $out_fh = *STDOUT;
    }
    else {
        open $out_fh, ">", $opt->{outfile};
    }

    {
        my $content = '';    # content of one block
        while (1) {
            last if $in_fh->eof and $content eq '';
            my $line = '';
            if ( !$in_fh->eof ) {
                $line = $in_fh->getline;
            }
            if ( ( $line eq '' or $line =~ /^\s+$/ ) and $content ne '' ) {
                my $info_of = App::Fasops::parse_block($content);
                $content = '';

                my $keep = '';
                if ( $opt->{first} ) {
                    $keep = ( keys %{$info_of} )[0];
                }

                for my $name ( keys %{$info_of} ) {
                    if ( $seen{$name} or $name eq $keep ) {
                        printf {$out_fh} ">%s\n",
                            App::Fasops::encode_header( $info_of->{$name} );
                        printf {$out_fh} "%s\n", $info_of->{$name}{seq};
                    }
                }
                print {$out_fh} "\n";
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

#----------------------------------------------------------#
# names
#----------------------------------------------------------#
package App::Fasops::Command::names;

use App::Fasops -command;

use constant abstract => 'scan a blocked fasta file and output all names';

sub opt_spec {
    return (
        [ "outfile|o=s", "Output filename. [stdout] for screen." ],
        [ "count|c",     "Also count name occurrences" ],
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
    $desc .= "Scan a blocked fasta file and output all names used in it.\n";
    $desc
        .= "\t<infile> is the path to blocked fasta file, .fas.gz is supported.\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error("This command need a input file.") unless @$args;
    $self->usage_error("The input file [@{[$args->[0]]}] doesn't exist.")
        unless -e $args->[0];

    if ( !exists $opt->{outfile} ) {
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".list";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $in_fh = IO::Zlib->new( $args->[0], "rb" );

    tie my %count_of, "Tie::IxHash";
    {
        my $content = '';    # content of one block
        while (1) {
            last if $in_fh->eof and $content eq '';
            my $line = '';
            if ( !$in_fh->eof ) {
                $line = $in_fh->getline;
            }
            if ( ( $line eq '' or $line =~ /^\s+$/ ) and $content ne '' ) {
                my $info_of = App::Fasops::parse_block($content);
                $content = '';

                for my $key ( keys %{$info_of} ) {
                    my $name = $info_of->{$key}{name};
                    $count_of{$name}++;
                }
            }
            else {
                $content .= $line;
            }
        }
    }
    $in_fh->close;

    my $out_fh;
    if ( lc( $opt->{outfile} ) eq "stdout" ) {
        $out_fh = *STDOUT;
    }
    else {
        open $out_fh, ">", $opt->{outfile};
    }
    for ( keys %count_of ) {
        print {$out_fh} $_;
        print {$out_fh} "\t" . $count_of{$_} if $opt->{count};
        print {$out_fh} "\n";
    }
    close $out_fh;

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
            "the threshold of alignment length, default is [1]",
            { default => 1 }
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
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".fas";
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

#----------------------------------------------------------#
# maf2fas
#----------------------------------------------------------#
package App::Fasops::Command::maf2fas;

use App::Fasops -command;

use constant abstract => 'convert maf to blocked fasta';

sub opt_spec {
    return (
        [ "outfile|o=s", "output filename" ],
        [   "length|l=i",
            "the threshold of alignment length, default is [1]",
            { default => 1 }
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
        .= "Convert UCSC maf multiply alignment file to blocked fasta file.\n";
    $desc .= "\t<infile> is the path to maf file, .maf.gz is supported\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error("This command need a input file.") unless @$args;
    $self->usage_error("The input file [@{[$args->[0]]}] doesn't exist.")
        unless -e $args->[0];

    if ( !exists $opt->{outfile} ) {
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".fas";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $in_fh = IO::Zlib->new( $args->[0], "rb" );
    open my $out_fh, ">", $opt->{outfile};

    # read and write
    my $content = '';
ALN: while ( my $line = <$in_fh> ) {
        if ( $line =~ /^\s+$/ and $content =~ /\S/ ) {    # meet blank line
            my @slines = grep {/\S/} split /\n/, $content;
            $content = '';

            # parse maf
            my @names;
            my $info_of = {};
            for my $sline (@slines) {
                my ( $s, $src, $start, $size, $strand, $srcsize, $text )
                    = split /\s+/, $sline;

                my ( $species, $chr_name ) = split /\./, $src;
                $chr_name = $species if !defined $chr_name;

                # adjust coordinates to be one-based inclusive
                $start = $start + 1;

                push @names, $species;
                $info_of->{$species} = {
                    seq        => $text,
                    name       => $species,
                    chr_name   => $chr_name,
                    chr_start  => $start,
                    chr_end    => $start + $size - 1,
                    chr_strand => $strand,
                };
            }

            # output
            for my $species (@names) {
                printf {$out_fh} ">%s\n",
                    App::Fasops::encode_header( $info_of->{$species} );
                printf {$out_fh} "%s\n", $info_of->{$species}{seq};
            }
            print {$out_fh} "\n";
        }
        elsif ( $line =~ /^#/ ) {    # comments
            next;
        }
        elsif ( $line =~ /^s\s/ ) {    # s line, contain info and seq
            $content .= $line;
        }
        else {                         # a, i, e, q lines
                # just ommit it
                # see http://genome.ucsc.edu/FAQ/FAQformat.html#format5
        }
    }

    $in_fh->close;
    close $out_fh;
}

1;
