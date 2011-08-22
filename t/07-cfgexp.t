# t/06-cfgexp.t
#
# vim: syntax=perl

use Test::More tests => 2;

use strict;
use warnings;

my $cfgexp     = 'bin/cfgexp';
my $gittestdir = qw( t/01-initdb.git );
my $ver1       = 'bcd156cb443a8812f444015053cadf3f1f55cc1a';
my $ver2       = 'bde0ab785072417fa506de689ae2620ad004e649';
my $ver3       = '1a63c13cc7918128e8a5ffba6d6fb82ca068bbf7';

if ( not -d $gittestdir ) {
    die "Test repo not found - did you run 01-initdb.t already?";
}

my $out_text_v1   = <<EOF;
group1.ldap.password:  secret
group1.ldap.uri:  ldaps://example.org
group1.ldap.user:  openxpki
group1.ldap1.password:  secret1
group1.ldap1.uri:  ldaps://example1.org
group1.ldap1.user:  openxpki1
group2.ldap.password:  secret
group2.ldap.uri:  ldaps://example.org
group2.ldap.user:  openxpki
group2.ldap2.password:  secret2
group2.ldap2.uri:  ldaps://example2.org
group2.ldap2.user:  openxpki2
EOF

my $out_text_v3   = <<EOF;
group1.ldap1.password:  secret1
group1.ldap1.uri:  ldaps://example1.org
group1.ldap1.user:  openxpki1
group2.ldap2.password:  secret2
group2.ldap2.uri:  ldaps://example2.org
group2.ldap2.user:  openxpkiA
group3.ldap.password:  secret3
group3.ldap.uri:  ldaps://example3.org
group3.ldap.user:  openxpki3
EOF

is( `$cfgexp --dbpath $gittestdir`,
    $out_text_v3, 'output of text format' );

is( `$cfgexp --dbpath $gittestdir --format text --version $ver1`,
    $out_text_v1, 'output of initial text' );
