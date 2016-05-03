requires 'App::Cmd';
requires 'AlignDB::IntSpan';
requires 'List::MoreUtils';
requires 'IO::Zlib';
requires 'Path::Tiny';
requires 'Tie::IxHash';
requires 'YAML::Syck';
requires 'perl', '5.010000';

on test => sub {
    requires 'Test::More', 0.88;
};
