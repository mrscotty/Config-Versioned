#!perl -T

use Test::More tests => 1;


# remove artifacts from previous run
BEGIN {
my $gittestdir = 't/00-load.git';
use Path::Class;
use DateTime;
dir($gittestdir)->rmtree;
}

my $gittestdir = 't/00-load.git';


package MyConfig;

base Config::Versioned;

# override parent method to be able to inject configuration
sub _import {
    my ($class) = shift;
    my %params = @_;
    $params{dbpath} = $gittestdir;
    $params{filename} = '00-load.conf';
    $params{path} = [ qw( t ) ];
    commit_time => DateTime->from_epoch( epoch => 1240341682 ),
    author_name => 'Test User',
    author_mail => 'test@example.com',
}

package main;

use_ok( 'MyConfig' );

diag("Testing Config::Versioned $Config::Versioned::VERSION, Perl $], $^X");
