# t/08-sha.t
#
# This test script is for the optional external parsing of
# configuration files using Config::Merge.
#
# It specifically tries to address a problem I was having with the SHA1
# hash working correctly on my Mac but not on Ubuntu
#
# vim: syntax=perl

BEGIN {
    use vars qw( $req_cm_err );
    eval 'require Config::Merge;';
    $req_cm_err = $@;
}

use Test::More tests => 3;
use DateTime;
use Path::Class;
use Data::Dumper;
use Carp qw(confess);

my $ver1 = '777fd3790995c010b20a9d7af47ec4d72d472b3e';

my $gitdb  = 't/08-sha.git';
my $cfgdir = 't/08-sha.d';

dir($gitdb)->rmtree;

package MyConfig;

use Moose;

extends 'Config::Versioned';

use Data::Dumper;

sub parser {
    my $self     = shift;
    my $params   = shift;
    my $filename = '';

    my $cm    = Config::Merge->new($cfgdir);
    my $cmref = $cm->();

    my $tree = $self->cm2tree($cmref);

    $params->{comment} = 'import from ' . $filename . ' using Config::Merge';

    if ( not $self->commit( $tree, $params ) ) {
        die "Error committing import from $filename: $@";
    }
}

sub cm2tree {
    my $self = shift;
    my $cm   = shift;

    if ( ref($cm) eq 'HASH' ) {
        my $ret = {};
        foreach my $key ( keys %{$cm} ) {
            $ret->{$key} = $self->cm2tree( $cm->{$key} );
        }
        return $ret;
    }
    elsif ( ref($cm) eq 'ARRAY' ) {
        my $ret = {};
        my $i   = 0;
        foreach my $entry ( @{$cm} ) {
            $ret->{ $i++ } = $self->cm2tree($entry);
        }
        return $ret;
    }
    else {
        return $cm;
    }
}

package main;

SKIP: {
    skip "Config::Merge not installed", 5 if $req_cm_err;
    my $cfg = MyConfig->new( {
    dbpath      => $gitdb,
    commit_time => DateTime->from_epoch( epoch => 1240341682 ),
    author_name => 'Test User',
    author_mail => 'test@example.com',
    autocreate  => 1,
}
    );

    ok( $cfg, 'created MyConfig instance' );
    is( $cfg->version, $ver1, 'check version of HEAD' );

    is( $cfg->get('port.host1'), '123', 'Check param port.host1' );
}
