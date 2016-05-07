package App::Fasops::Command::covers;
use strict;
use warnings;
use autodie;

use App::Fasops -command;
use App::Fasops::Common;

use constant abstract => 'scan blocked fasta files and output covers on chromosomes';

sub opt_spec {
    return (
        [ "outfile|o=s", "Output filename. [stdout] for screen." ],
        [ "name|n=s",    "Only output this species." ],
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
        $opt->{outfile} = Path::Tiny::path( $args->[0] )->absolute . ".yml";
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    my %count_of;    # YAML::Sync can't Dump tied hashes
    for my $infile ( @{$args} ) {
        my $in_fh = IO::Zlib->new( $infile, "rb" );

        my $content = '';    # content of one block
        while (1) {
            last if $in_fh->eof and $content eq '';
            my $line = '';
            if ( !$in_fh->eof ) {
                $line = $in_fh->getline;
            }
            next if substr( $line, 0, 1 ) eq "#";

            if ( ( $line eq '' or $line =~ /^\s+$/ ) and $content ne '' ) {
                my $info_of = App::Fasops::Common::parse_block($content);
                $content = '';

                my @names = keys %{$info_of};
                if ( $opt->{name} ) {
                    if ( exists $info_of->{ $opt->{name} } ) {
                        @names = ( $opt->{name} );
                    }
                    else {
                        warn "$opt->{name} doesn't exist in this alignment\n";
                        next;
                    }
                }

                for my $key (@names) {
                    my $name     = $info_of->{$key}{name};
                    my $chr_name = $info_of->{$key}{chr_name};

                    if ( !exists $count_of{$name} ) {
                        $count_of{$name} = {};
                    }
                    if ( !exists $count_of{$name}->{$chr_name} ) {
                        $count_of{$name}->{$chr_name} = AlignDB::IntSpan->new;
                    }

                    $count_of{$name}->{$chr_name}
                        ->add_pair( $info_of->{$key}{chr_start}, $info_of->{$key}{chr_end} );
                }
            }
            else {
                $content .= $line;
            }
        }

        $in_fh->close;
    }

    # IntSpan to runlist
    for my $name ( keys %count_of ) {
        for my $chr_name ( keys %{ $count_of{$name} } ) {
            $count_of{$name}->{$chr_name} = $count_of{$name}->{$chr_name}->runlist;
        }
    }

    my $out_fh;
    if ( lc( $opt->{outfile} ) eq "stdout" ) {
        $out_fh = *STDOUT;
    }
    else {
        open $out_fh, ">", $opt->{outfile};
    }

    if ( defined $opt->{name} ) {
        print {$out_fh} YAML::Syck::Dump( $count_of{ $opt->{name} } );
    }
    else {
        print {$out_fh} YAML::Syck::Dump( \%count_of );
    }
    close $out_fh;
}

1;
