package App::Fasops::Command::xlsx;
use strict;
use warnings;
use autodie;

use Excel::Writer::XLSX;

use App::Fasops -command;
use App::Fasops::Common;

sub abstract {
    return 'paint substitutions and indels to an excel file';
}

sub opt_spec {
    return (
        [ "outfile|o=s", "Output filename. [stdout] for screen" ],
        [ "length|l=i", "the threshold of alignment length", { default => 1 } ],
        [ 'wrap=i',     'wrap length',                       { default => 50 }, ],
        [ 'spacing=i',  'wrapped line spacing',              { default => 1 }, ],
        [ 'colors=i',   'number of colors',                  { default => 15 }, ],
        [ 'section=i', 'start section', { default => 1, hidden => 1 }, ],
        [ 'outgroup',  'alignments have an outgroup', ],
        [ 'noindel',   'omit indels', ],
        [ 'nosingle',  'omit singleton SNPs and indels', ],
        [ 'nocomplex', 'omit complex SNPs and indels', ],
        { show_defaults => 1, }
    );
}

sub usage_desc {
    return "fasops xlsx [options] <infile>";
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= <<'MARKDOWN';

* <infiles> are paths to axt files, .axt.gz is supported
* infile == stdin means reading from STDIN

MARKDOWN

    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    if ( @{$args} != 1 ) {
        my $message = "This command need one input file.\n\tIt found";
        $message .= sprintf " [%s]", $_ for @{$args};
        $message .= ".\n";
        $self->usage_error($message);
    }
    for ( @{$args} ) {
        next if lc $_ eq "stdin";
        if ( !Path::Tiny::path($_)->is_file ) {
            $self->usage_error("The input file [$_] doesn't exist.");
        }
    }

    if ( !exists $opt->{outfile} ) {
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".xlsx";
    }

    if ( $opt->{colors} ) {
        $opt->{colors} = List::Util::min( $opt->{colors}, 15 );
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    #@type IO::Handle
    my $in_fh;
    if ( lc $args->[0] eq "stdin" ) {
        $in_fh = *STDIN{IO};
    }
    else {
        $in_fh = IO::Zlib->new( $args->[0], "rb" );
    }

    # Create workbook and worksheet objects
    #@type Excel::Writer::XLSX
    my $workbook = Excel::Writer::XLSX->new( $opt->{outfile} );

    #@type Excel::Writer::XLSX::Worksheet
    my $worksheet = $workbook->add_worksheet;

    my $format_of       = create_formats($workbook);
    my $max_name_length = 1;

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

            my @full_names;
            my $seq_refs = [];

            for my $key ( keys %{$info_of} ) {
                push @full_names, $key;
                push @{$seq_refs}, $info_of->{$key}{seq};
            }

            if ( $opt->{length} ) {
                next if length $info_of->{ $full_names[0] }{seq} < $opt->{length};
            }

            print "Section [$opt->{section}]\n";
            $max_name_length = List::Util::max( $max_name_length, map {length} @full_names );

            # including indels and snps
            my $vars = App::Fasops::Common::get_vars( $seq_refs, $opt );
            $opt->{section} = App::Fasops::Common::paint_vars( $worksheet, $format_of, $opt, $vars,
                \@full_names );

        }
        else {
            $content .= $line;
        }
    }

    $in_fh->close;

    # format column
    $worksheet->set_column( 0, 0, $max_name_length + 1 );
    $worksheet->set_column( 1, $opt->{wrap} + 3, 1.6 );

    return;
}

# Excel formats
sub create_formats {

    #@type Excel::Writer::XLSX
    my $workbook = shift;

    my $format_of = {};

    # species name
    $format_of->{name} = $workbook->add_format(
        font => 'Courier New',
        size => 10,
    );

    # variation position
    $format_of->{pos} = $workbook->add_format(
        font     => 'Courier New',
        size     => 8,
        align    => 'center',
        valign   => 'vcenter',
        rotation => 90,
    );

    $format_of->{snp}   = {};
    $format_of->{indel} = {};

    # background
    my $bg_of = {};

    # 15
    my @colors = (
        22,    # Gray-25%, silver
        43,    # Light Yellow       0b001
        42,    # Light Green        0b010
        27,    # Lite Turquoise
        44,    # Pale Blue          0b100
        46,    # Lavender
        47,    # Tan
        24,    # Periwinkle
        49,    # Aqua
        51,    # Gold
        45,    # Rose
        52,    # Light Orange
        26,    # Ivory
        29,    # Coral
        31,    # Ice Blue

        #        30,    # Ocean Blue
        #        41,    # Light Turquoise, again
        #        48,    # Light Blue
        #        50,    # Lime
        #        54,    # Blue-Gray
        #        62,    # Indigo
    );

    for my $i ( 0 .. $#colors ) {
        $bg_of->{$i}{bg_color} = $colors[$i];

    }
    $bg_of->{unknown}{bg_color} = 9;    # White

    # snp base
    my $snp_fg_of = {
        'A' => { color => 58, },        # Dark Green
        'C' => { color => 18, },        # Dark Blue
        'G' => { color => 28, },        # Dark Purple
        'T' => { color => 16, },        # Dark Red
        'N' => { color => 8, },         # Black
        '-' => { color => 8, },         # Black
    };

    for my $fg ( keys %{$snp_fg_of} ) {
        for my $bg ( keys %{$bg_of} ) {
            $format_of->{snp}{"$fg$bg"} = $workbook->add_format(
                font   => 'Courier New',
                size   => 10,
                align  => 'center',
                valign => 'vcenter',
                %{ $snp_fg_of->{$fg} },
                %{ $bg_of->{$bg} },
            );
        }
    }
    $format_of->{snp}{'-'} = $workbook->add_format(
        font   => 'Courier New',
        size   => 10,
        align  => 'center',
        valign => 'vcenter',
    );

    for my $bg ( keys %{$bg_of} ) {
        $format_of->{indel}->{$bg} = $workbook->add_format(
            font   => 'Courier New',
            size   => 10,
            bold   => 1,
            align  => 'center',
            valign => 'vcenter',
            %{ $bg_of->{$bg} },
        );
    }

    return $format_of;
}

1;
