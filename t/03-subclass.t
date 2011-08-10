# t/03-subclass.t
#
# vim: syntax=perl

use Test::More tests => 2;

my $ver1 = 'bcd156cb443a8812f444015053cadf3f1f55cc1a';
my $ver2 = 'bde0ab785072417fa506de689ae2620ad004e649';
my $ver3 = '1a63c13cc7918128e8a5ffba6d6fb82ca068bbf7';

my $gittestdir = 't/01-initdb.git';

package MyConfig;

use base qw( Config::Versioned );

# override parent method to be able to inject configuration
sub _import_disabled {
    my ($class) = shift;
    my %params = @_;
    $params{dbpath} = $gittestdir;
    $params{filename} = '00-load.conf';
    $params{path} = [ qw( t ) ];
    $params{commit_time} = DateTime->from_epoch( epoch => 1240341682 );
    $params{author_name} = 'Test User';
    $params{author_mail} = 'test@example.com';
    $class->SUPER::_import( %params );
}

sub new {
    my ( $this ) = shift;
    my $class = ref($this) || $this;

    $this->SUPER::new( dbpath => $gittestdir );
}

package main;

if ( not -d $gittestdir ) {
    die "Test repo not found - did you run 01-initdb.t already?";
}


#use_ok( 'MyConfig' );
my $cfg = MyConfig->new();
ok( $cfg, 'created MyConfig instance' );
is( $cfg->version, $ver3, 'check version of HEAD');

diag("Testing Config::Versioned $Config::Versioned::VERSION, Perl $], $^X");