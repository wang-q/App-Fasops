package App::Fasops;

our $VERSION = '0.3.0';

use App::Cmd::Setup -app;

1;

__END__

=head1 NAME

App::Fasops - operating blocked fasta files

=head1 SYNOPSIS

    commands: list the application's commands
        help: display a command's help screen
  
     axt2fas: convert axt to blocked fasta
      covers: scan blocked fasta files and output covers on chromosomes
     maf2fas: convert maf to blocked fasta
       names: scan blocked fasta files and output all species names
    separate: separate blocked fasta files by species
       split: split blocked fasta files to separate per-alignment files
      subset: extract a subset of names from a blocked fasta

See C<fasops commands> for usage information.

=cut

=head1 LICENSE

Copyright 2014- Qiang Wang

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

Qiang Wang

=cut
