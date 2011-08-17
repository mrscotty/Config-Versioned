# t/02-readonly.t
#
# vim: syntax=perl

use Test::More tests => 3;

use strict;
use warnings;

my $gittestdir = qw( t/01-initdb.git );
my $ver1       = 'bcd156cb443a8812f444015053cadf3f1f55cc1a';
my $ver2       = 'bde0ab785072417fa506de689ae2620ad004e649';
my $ver3       = '1a63c13cc7918128e8a5ffba6d6fb82ca068bbf7';

if ( not -d $gittestdir ) {
    die "Test repo not found - did you run 01-initdb.t already?";
}

use_ok( 'Config::Versioned', { dbpath => $gittestdir } );

my $cfg = Config::Versioned->new();
ok( $cfg, 'create new config instance' );
is( $cfg->version, $ver3, 'check version of HEAD' );
