package App::Fasops::Command::separate;

use App::Fasops -command;

use constant abstract => 'separate blocked fasta files by species';

sub opt_spec {
    return (
        [ "outdir|o=s", "output location, default is [.]",                { default => '.' } ],
        [ "ext|e=s",    "extensions of output files, default is [fasta]", { default => 'fasta' } ],
        [ "rm|r",       "if outdir exists, remove it before operating" ],
        [ "rc",         "Revcom sequences when chr_strand is '-'" ],
        [ "nodash",     "Remove dashes ('-') from sequences" ],
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
    $desc .= "Separate blocked fasta files by species.\n";
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

    if ( !exists $opt->{outdir} ) {
        $opt->{outdir} = Path::Tiny::path( $args->[0] )->absolute . ".separate";
    }
    if ( -e $opt->{outdir} ) {
        if ( $opt->{rm} ) {
            Path::Tiny::path( $opt->{outdir} )->remove_tree;
        }
    }

    Path::Tiny::path( $opt->{outdir} )->mkpath;
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    for my $infile ( @{$args} ) {
        my $in_fh = IO::Zlib->new( $args->[0], "rb" );

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
                    my $info = $info_of->{$key};
                    if ( $opt->{nodash} ) {
                        $info->{seq} =~ tr/-//d;
                    }
                    if ( $opt->{rc} and $info->{chr_strand} ne "+" ) {
                        $info->{seq}        = App::Fasops::revcom( $info->{seq} );
                        $info->{chr_strand} = "+";
                    }

                    my $outfile
                        = Path::Tiny::path( $opt->{outdir}, $info->{name} . '.' . $opt->{ext} );
                    $outfile->append( ">" . App::Fasops::encode_header($info) . "\n" );
                    $outfile->append( $info->{seq} . "\n" );
                }
            }
            else {
                $content .= $line;
            }
        }

        $in_fh->close;
    }
}

1;