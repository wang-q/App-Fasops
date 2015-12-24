package App::Fasops::Command::names;

use App::Fasops -command;

use constant abstract => 'scan blocked fasta files and output all species names';

sub opt_spec {
    return (
        [ "outfile|o=s", "Output filename. [stdout] for screen." ],
        [ "count|c",     "Also count name occurrences" ],
    );
}

sub usage_desc {
    my $self = shift;
    my $desc = $self->SUPER::usage_desc;    # "%c COMMAND %o"
    $desc .= " <infiles>";
    return $desc;
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= "\t<infiles> are paths to blocked fasta files, .fas.gz is supported.\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error("This command need one or more input files.") unless @{$args};
    for ( @{$args} ) {
        if ( !Path::Tiny::path($_)->is_file ) {
            $self->usage_error("The input file [$_] doesn't exist.");
        }
    }

    if ( !exists $opt->{outfile} ) {
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".list";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    tie my %count_of, "Tie::IxHash";
    for my $infile ( @{$args} ) {
        my $in_fh = IO::Zlib->new( $infile, "rb" );

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

        $in_fh->close;
    }

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
