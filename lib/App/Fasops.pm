package App::Fasops;

our $VERSION = '0.4.8';

use strict;
use warnings;
use App::Cmd::Setup -app;

# TODO: command chop
# TODO: command create

1;

__END__

=head1 NAME

App::Fasops - operating blocked fasta files

=head1 SYNOPSIS

    fasops <command> [-?h] [long options...]
        -? -h --help    show help

    Available commands:

      commands: list the application's commands
          help: display a command's help screen

       axt2fas: convert axt to blocked fasta
        covers: scan blocked fasta files and output covers on chromosomes
         links: scan blocked fasta files and output links between pieces
       maf2fas: convert maf to blocked fasta
         names: scan blocked fasta files and output all species names
        refine: realign alignments
       replace: replace headers from a blocked fasta
      separate: separate blocked fasta files by species
         slice: extract alignment slices from a blocked fasta
         split: split blocked fasta files to separate per-alignment files
        subset: extract a subset of species from a blocked fasta

See C<fasops commands> for usage information.

=head1 AUTHOR

Qiang Wang <wang-q@outlook.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Qiang Wang.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
