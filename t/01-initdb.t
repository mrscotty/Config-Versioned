## t/01-initdb.t
##
## Written 2011 by Scott Hardin for the OpenXPKI project
## Copyright (C) 2010, 2011 by Scott T. Hardin
##
## vim: syntax=perl

use Test::More tests => 21;

use strict;
use warnings;
my $gittestdir = qw( t/01-initdb.git );

my $ver1 = 'bcd156cb443a8812f444015053cadf3f1f55cc1a';
my $ver2 = 'bde0ab785072417fa506de689ae2620ad004e649';
my $ver3 = '1a63c13cc7918128e8a5ffba6d6fb82ca068bbf7';

BEGIN {
    my $gittestdir = qw( t/01-initdb.git );

    # remove artifacts from previous run
    use Path::Class;
    use DateTime;
    dir($gittestdir)->rmtree;

    # fire it up!
    use_ok(
        'Config::Versioned',
        {
            dbpath      => $gittestdir,
            autocreate  => 1,
            filename    => '01-initdb.conf',
            path        => [qw( t )],
            commit_time => DateTime->from_epoch( epoch => 1240341682 ),
            author_name => 'Test User',
            author_mail => 'test@example.com',
        }
    );
}

##
## BASIC INIT
##

my $cfg = Config::Versioned->new();
ok( $cfg, 'create new config instance' );

# Internals: check that the head really points to a commit object
is( $Config::Versioned::git->head->kind, 'commit', 'head should be a commit' );

is( $cfg->version, $ver1, 'check version (sha1 hash) of first commit' );

# force a re-load of the configuration file we already used to ensure
# that we don't add a commit when there were no changes
$cfg->parser();
is( $cfg->version, $ver1, 're-import should not create new commit' );

# check the internal helper functions
my ( $s1, $k1 ) = $cfg->_get_sect_key('group1.ldap');
is( $s1, 'group1', "_get_sect_key section" );
is( $k1, 'ldap',   "_get_sect_key section" );

my $obj = $cfg->_findobj('group.ldap');
is( $obj, undef, '_findobj for group.ldap should fail' );

$obj = $cfg->_findobj('group1.ldap1');
is( ref($obj), 'Git::PurePerl::Object::Tree',
    '_findobj for group1.ldap1 should return an object' );
is( $obj->kind, 'tree', "_findobj() returns tree" );

$obj = $cfg->_findobj('group1.ldap1.uri');
is( $obj->kind, 'blob', "_findobj() returns blob" );

is( $cfg->get('group1.ldap1.uri'),
    'ldaps://example1.org', "check single attribute" );

my $cfg2 = Config::Versioned->new( { prefix => 'group2' } );
ok( $cfg2, 'create new config instance with prefix' );

is( $cfg2->{prefix}, 'group2', 'check internal hash for prefix' );

is( $cfg2->get('ldap.uri'),
    'ldaps://example.org', "check single attribute with prefix" );

$cfg->parser(
    {
        filename    => '01-initdb-2.conf',
        path        => [qw( t )],
        commit_time => DateTime->from_epoch( epoch => 1240351682 ),
        author_name => 'Test User',
        author_mail => 'test@example.com',
    }
);
is( $cfg->version, $ver2, 'check version of second commit' );

$cfg->parser(
    {
        filename    => '01-initdb-3.conf',
        path        => [qw( t )],
        commit_time => DateTime->from_epoch( epoch => 1240361682 ),
        author_name => 'Test User',
        author_mail => 'test@example.com',
    }
);
is( $cfg->version, $ver3, 'check version of third commit' );

# Try to get different versions of some values
is( $cfg->get('group2.ldap2.user'),
    'openxpkiA', "newest version of group2.ldap2.user" );
is( $cfg->get( 'group2.ldap2.user', $ver1 ),
    'openxpki2', "oldest version of group2.ldap2.user" );

# sort 'em just to be on the safe side
my @attrlist = sort( $cfg->listattr('group1.ldap1') );
is_deeply( \@attrlist, [ sort(qw( uri user password )) ], "check attr list" );

my @attrlist2 = sort( $cfg2->listattr('ldap2') );
is_deeply(
    \@attrlist2,
    [ sort(qw( uri user password )) ],
    "check attr list with prefix"
);

