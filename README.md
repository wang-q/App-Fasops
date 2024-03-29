[![Actions Status](https://github.com/wang-q/App-Fasops/actions/workflows/build.yml/badge.svg)](https://github.com/wang-q/App-Fasops/actions) [![Build Status](https://travis-ci.org/wang-q/App-Fasops.svg?branch=master)](https://travis-ci.org/wang-q/App-Fasops) [![Coverage Status](http://codecov.io/github/wang-q/App-Fasops/coverage.svg?branch=master)](https://codecov.io/github/wang-q/App-Fasops?branch=master) [![MetaCPAN Release](https://badge.fury.io/pl/App-Fasops.svg)](https://metacpan.org/release/App-Fasops)
# NAME

App::Fasops - operating blocked fasta files

# SYNOPSIS

    fasops <command> [-?h] [long options...]
            -? -h --help  show help

    Available commands:

       commands: list the application's commands
           help: display a command's help screen

        axt2fas: convert axt to blocked fasta
          check: check genome locations in (blocked) fasta headers
         concat: concatenate sequence pieces in blocked fasta files
      consensus: create consensus from blocked fasta file
         covers: scan blocked fasta files and output covers on chromosomes
           join: join multiple blocked fasta files by common target
          links: scan blocked fasta files and output bi/multi-lateral range links
        maf2fas: convert maf to blocked fasta
       mergecsv: merge csv files based on @fields
          names: scan blocked fasta files and output all species names
         refine: realign blocked fasta file with external programs
        replace: replace headers from a blocked fasta
       separate: separate blocked fasta files by species
          slice: extract alignment slices from a blocked fasta
          split: split blocked fasta files to per-alignment files
           stat: basic statistics on alignments
         subset: extract a subset of species from a blocked fasta
           xlsx: paint substitutions and indels to an excel file

See `fasops commands` for usage information.

# AUTHOR

Qiang Wang <wang-q@outlook.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Qiang Wang.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
