# t/04-parser.t
#
# This test script is for the optional external parsing of
# configuration files using Config::Merge.
#
# vim: syntax=perl

BEGIN {
    eval 'require Config::Merge;';
    our $req_cm_err = $@;
}

use Test::More tests => 5;
use DateTime;
use Path::Class;
use Data::Dumper;
use Carp qw(confess);

my $ver1 = '74e91b983e0fa5265e09f28e7b6f176850e04fcf';

my $gitdb = 't/05-config-merge.git';

dir($gitdb)->rmtree;

package MyConfig;

use base qw( Config::Versioned );
use Data::Dumper;

sub new {
    my ($this) = shift;
    my $class = ref($this) || $this;
    my $params = shift;

    $params->{dbpath}      = $gitdb;
    $params->{commit_time} = DateTime->from_epoch( epoch => 1240341682 );
    $params->{author_name} = 'Test User';
    $params->{author_mail} = 'test@example.com';

    $this->SUPER::new($params);

}

sub parser {
    my $self     = shift;
    my $params   = shift;
    my $filename = '';

    my $cm    = Config::Merge->new('t/05-config-merge.d');
    my $cmref = $cm->();

    my $tree = $self->cm2tree($cmref);

    #    warn "Config::Merge TREE: ", Dumper($tree), "\n";
    
    $params->{comment} = 'import from ' . $filename . ' using Config::Merge';

    $self->commit( $tree, $params );
}

sub cm2tree {
    my $self = shift;
    my $cm   = shift;
    my $tree = {};
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
    skip "Config::Merge not installed", 2 if $req_cm_err;
    my $cfg = MyConfig->new();

    ok( $cfg, 'created MyConfig instance' );
    is( $cfg->version, $ver1, 'check version of HEAD' );

    is( $cfg->get('db.hosts.1'),    'host2', 'Check param db.hosts.1' );
    is( $cfg->get('db.port.host2'), '789',   'Check param db.hosts.1' );

    my @attrlist = sort( $cfg->listattr('db.port') );
    is_deeply(
        \@attrlist,
        [ sort(qw( host1 host2 )) ],
        'Check attr list at db.port'
    );
}
