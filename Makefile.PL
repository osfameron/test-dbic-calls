use strict;
use warnings;
use inc::Module::Install;

name        'Test-DBIx-Class-Stats';
all_from    'lib/Test/DBIx/Class/Stats.pm';

license     'perl';
author      'osfameron';

requires      'DBIx::Class';
requires      'Moo';
requires      'MooX::HandlesVia';
requires      'Time::HiRes';
requires      'Test::More' => 0.42;

test_requires 'Test::DBIx::Class';

auto_install;
WriteAll;
