package App::Fasops;

our $VERSION = '0.4.9';

use strict;
use warnings;
use App::Cmd::Setup -app;

# TODO: command chop
#
##----------------------------#
## trim head and tail indels
##----------------------------#
##  If head length set to 1, the first indel will be trimmed
##  Length set to 5 and the second indel will also be trimmed
##   GAAA--C
##   --AAAGC
##   GAAAAGC
#sub trim_head_tail {
#    my $seq_of      = shift;
#    my $seq_names   = shift;
#    my $head_length = shift;    # indels in this region will also be trimmed
#    my $tail_length = shift;    # indels in this region will also be trimmed
#
#    # default value means only trim indels starting at the first base
#    $head_length = defined $head_length ? $head_length : 1;
#    $tail_length = defined $tail_length ? $tail_length : 1;
#
#    my $seq_number   = scalar @{$seq_names};
#    my $align_length = length $seq_of->{ $seq_names->[0] };
#
#    my $align_set = AlignDB::IntSpan->new("1-$align_length");
#    my $indel_set = AlignDB::IntSpan->new;
#
#    for my $n ( @{$seq_names} ) {
#        my $seq_indel_set = find_indel_set( $seq_of->{$n} );
#        $indel_set->merge($seq_indel_set);
#    }
#
#    # record bp chopped
#    my %head_chopped = map { $_ => 0 } @{$seq_names};
#    my %tail_chopped = map { $_ => 0 } @{$seq_names};
#
#    # There're no indels at all
#    return ( \%head_chopped, \%tail_chopped ) if $indel_set->is_empty;
#
#    # head indel(s) to be trimmed
#    my $head_set = AlignDB::IntSpan->new;
#    $head_set->add_range( 1, $head_length );
#    my $head_indel_set = $indel_set->find_islands($head_set);
#
#    # head indels
#    if ( $head_indel_set->is_not_empty ) {
#        for my $i ( 1 .. $head_indel_set->max ) {
#            my @column;
#            for my $n ( @{$seq_names} ) {
#                my $base = substr( $seq_of->{$n}, 0, 1, '' );
#                if ( $base ne '-' ) {
#                    $head_chopped{$n}++;
#                }
#            }
#        }
#    }
#
#    # tail indel(s) to be trimmed
#    my $tail_set = AlignDB::IntSpan->new;
#    $tail_set->add_range( $align_length - $tail_length + 1, $align_length );
#    my $tail_indel_set = $indel_set->find_islands($tail_set);
#
#    # tail indels
#    if ( $tail_indel_set->is_not_empty ) {
#        for my $i ( $tail_indel_set->min .. $align_length ) {
#            my @column;
#            for my $n ( @{$seq_names} ) {
#                my $base = substr( $seq_of->{$n}, -1, 1, '' );
#                if ( $base ne '-' ) {
#                    $tail_chopped{$n}++;
#                }
#            }
#        }
#    }
#
#    return ( \%head_chopped, \%tail_chopped );
#}


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
