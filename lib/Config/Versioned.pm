## Config::Versioned
##
## Written 2011 by Scott T. Hardin for the OpenXPKI project
## Copyright (C) 2010, 2011 by The OpenXPKI Project
##
## Based on the CPAN module App::Options
##
## vim: syntax=perl

package Config::Versioned;

use strict;
use warnings;

=head1 NAME

Config::Versioned - Simple, versioned access to configuration data

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use Carp;
use Config::Std;
use Data::Dumper;
use DateTime;
use Git::PurePerl;
use Path::Class;

my $delimiter = '.';

# a reference to the singleton Config::Versioned object that parsed the command line
my ($default_option_processor);

my (%path_is_secure);

=head1 SYNOPSIS

    use Config::Versioned;

    my $cfg = Config::Versioned->new();
    my $param1 = $cfg->get('subsystem1.group.param1');
    my $old1 = $cfg->get('subsystem1.group.param1', $version);
    my @keys = $cfg->list('subsys1.db');

    my $cfg2 = Config::Versioned->new( prefix => 'subsystem1.group' );
    my $p1 = $cfg2->get('param1');
    my $p2 = $cfg2->get('param2');

=head1 DESCRIPTION

Config::Versioned allows an application to access configuration parameters
not only by parameter name, but also by version number. This allows for
the configuration subsystem to store previous versions of the configuration
parameters. When requesting the value for a specific attribute, the programmer
specifies whether to fetch the most recent value or a previous value.

This is useful for long-running tasks such as in a workflow-based application
where task-specific values (e.g.: profiles) are static over the life of a
workflow, while global values (e.g.: name of an LDAP server to be queried)
should always be the most recent.

Config::Versioned handles the versions by storing the configuration data
in an internal Git repository. Each import of configuration files into
the repository is documented with a commit. When a value is fetched, it is
this commit that is referenced directly when specifying the version.

The access to the individual attributes is via a named-parameter scheme, where 
the key is a dot-separated string.

Currently, C<Config::Std> is used for the import of the data files into the 
internal Git repository. Support for other configuration modules (e.g.:
C<Config::Any>) is planned.

=head1 METHODS

=head2 init()

This is invoked automatically via import(). It is called when running the
following code:

 use Config::Versioned;

The init() method reads the configuration data from the configuration files
and populates an internal data structure.

Optionally, parameters may be passed to init(). The following
named-parameters are supported:

=over 8

=item path

Specifies an anonymous array contianing the names of the directories to
check for the configuration files.

 path => qw( /etc/yourapp/etc /etc/yourapp/local/etc . ),

The default path is just the current directory.

=item filename

Specifies the name of the configuration file to be found in the given path.

 filename => qw( yourapp.conf ),

The default filename is "cfgver.conf".

=item dbpath

The directory for the internal git repository that stores the config.

 dbpath => qw( config.git ),

The default is "cfgver.git".

=item author_name, author_mail

The name and e-mail address to use in the internal git repository for
commits.

=item autocreate

If no internal git repository exists, it will be created during code
initialization. 

 autocreate => 1,

The default is "0".

Note: this option might become deprecated. I just wanted some extra
"insurance" during the early stages of development.

=item commit_time

This sets the time to use for the commits in the internal git repository.
It is used for debugging purposes only!

=back

=head2 new()

This is called during init() and creates an object instance. It may
also be called elsewhere and given a I<prefix> to restrict C<get()>
requests to a specific node.

=cut

sub new {
    my ($this) = shift;
    my $class = ref($this) || $this;
    my $self = {};
    my $init_args;
    if ( ref( $_[0] ) eq 'HASH' ) {
        $init_args = shift;
    }
    else {
        $init_args = {@_};
    }
    $self->{init_args} = $init_args;
    $self->{argv}      = [@ARGV];
    $self->{options}   = [];
    bless $self, $class;

    # process args

    foreach my $key (qw( prefix )) {
        $self->{$key} = $init_args->{$key};
    }
    return ($self);
}

=head2 isParam( LOCATION [, VERSION ] )

Returns true if the given LOCATION contains a parameter value and false
if it is a tree object containing subtrees or objects. In other words,
if you get a true value on a LOCATION, you can fetch the value of the 
parameter. Otherwise, you should use list() to see the names of the 
locations subordinate to this LOCATION.

NOTE: I don't like the wording of this, but it is more a
minor kludge in a proof-of-concept implementation.

=cut

sub isParam {
    die "isParam not implemented";
}

=head2 get( LOCATION [, VERSION ] )

This is the accessor for fetching the value(s) of the given parameter. The
value may either be zero or more elements.

In list context, the values are returned. In scalar context, C<undef> is 
returned if the variable is empty. Otherwise, the first element is returned.

Optionally, a VERSION may be specified to return the value for that
specific version.

=cut

sub get {
    my $self     = shift;
    my $location = shift;
    my $version  = shift;

    if ( $self->{prefix} ) {
        $location = $self->{prefix} . $delimiter . $location;
    }
    my $obj = $self->_findobj( $location, $version );

    if ( not defined $obj ) {
        return;
    }

    if ( $obj->kind eq 'blob' ) {
        return $obj->content;
    }
    else {
        warn "# DEBUG: get() was asked to return a non-blob object\n";
        return;
    }
}

=head2 listattr( LOCATION [, VERSION ] )

This fetches a list of the parameters available for a given location in the 
configuration tree.

=cut

sub listattr {
    my $self     = shift;
    my $location = shift;
    my $version  = shift;

    if ( $self->{prefix} ) {
        $location = $self->{prefix} . $delimiter . $location;
    }

    my $obj = $self->_findobj( $location, $version );
    if ( $obj and $obj->kind eq 'tree' ) {
        my @entries = $obj->directory_entries;
        my @ret     = ();
        foreach my $de (@entries) {
            push @ret, $de->filename;
        }
        return @ret;
    }
    else {
        $@ = "obj at $location not found";
        return;
    }
}

=head2 version

This returns the current version of the configuration database, which
happens to be the SHA1 hash of the HEAD of the internal git repository.

=cut

sub version {
    my $self = shift;

    my $head = $Config::versioned->head;
    return $head->sha1;
}

=head1 INTERNALS

=cut

# This translates the procedural Config::Versioned::import() into the class
# method Config::Versioned->_import() (for subclassing)

sub import {
    my ( $package, @args ) = @_;
    $package->_import(@args);
}

sub _import_test {
    my ( $class, @args ) = @_;
    $default_option_processor = undef;
    $class->_import(@args);
}

sub _import {
    my ( $class, @args ) = @_;

    # We only do this once (the default Config::Versioned option processor
    # is a singleton)

    if ( !$default_option_processor ) {

        # can supply initial hashref to use for option values instead of
        # global %App::options

        my $values =
          ( $#args > -1 && ref( $args[0] ) eq "HASH" )
          ? shift(@args)
          : \$Config::versioned;

        if ( not( $#args % 2 == 1 ) ) {
            croak
"Config::Versioned::import(): must have an even number of vars/values for named args";
        }
        my $init_args = {@args};

   # "values" in named arg list overrides the one supplied as an initial hashref

        if ( defined $init_args->{values} ) {
            ( ref( $init_args->{values} ) eq "HASH" )
              || croak
              "Config::Versioned->new(): 'values' arg must be a hash reference";
            $values = $init_args->{values};
        }

        my $option_processor = $class->new($init_args);
        $default_option_processor =
          $option_processor;    # save it in the singleton location

  #        $option_processor->_read_options($values)
  #          ;                     # read in all the options from various places

        $option_processor->{values} =
          $values;              # store it for future (currently undefined) uses

        if ( not defined $init_args->{path} ) {
            $init_args->{path} = [qw( . )];
        }
        elsif ( ref( $init_args->{path} ) ne 'ARRAY' ) {
            croak "Config::Versioned 'path' must be a reference to an ARRAY";
        }

        if ( not $init_args->{filename} ) {
            $init_args->{filename} = 'cfgver.conf';
        }

        if ( not $init_args->{dbpath} ) {
            $init_args->{dbpath} = 'cfgver.git';
        }

        my $git;
        if ( not -d $init_args->{dbpath} ) {
            dir( $init_args->{dbpath} )->mkpath;
            $git = Git::PurePerl->init( gitdir => $init_args->{dbpath} );
        }
        else {
            $git = Git::PurePerl->new( directory => $init_args->{dbpath} );
        }

        $Config::versioned = $git;

        $class->_import_cfg($init_args);

    }
}

=head2 _import_cfg INITARGS

Imports the configuration read and writes it to the internal database.

=cut

sub _import_cfg {
    my $self      = shift;
    my $init_args = shift;

    # Read the configuration from the import files

    my %tmpcfg = ();
    $default_option_processor->_read_config_path( $init_args->{filename},
        \%tmpcfg, @{ $init_args->{path} } );

    # convert the foreign data structure to a simple hash tree,
    # where the value is either a scalar or a hash reference.

    my $tmphash = {};
    foreach my $sect ( keys %tmpcfg ) {

        # build up the underlying branch for these leaves

        my @sectpath = split( /\./, $sect );
        my $sectref = $tmphash;
        foreach my $nodename (@sectpath) {
            $sectref->{$nodename} ||= {};
            $sectref = $sectref->{$nodename};
        }

        # now add the leaves

        foreach my $leaf ( keys %{ $tmpcfg{$sect} } ) {
            $sectref->{$leaf} = $tmpcfg{$sect}{$leaf};
        }

    }

    my $parent = undef;

    if ( $Config::versioned->all_sha1s->all ) {
        my $master = $Config::versioned->ref('refs/heads/master');
        if ( not $master ) {
            die "ERR: no master object found";
        }
        $parent = $master->sha1;
    }

    my $tree  = $self->_hash2tree($tmphash);
    my $actor = Git::PurePerl::Actor->new(
        name  => $init_args->{author_name} || "process: $0",
        email => $init_args->{author_mail} || $ENV{USER} . '@localhost',
    );

    my $time = $init_args->{commit_time} || DateTime->now;

    my @commit_attrs = (
        tree           => $tree->sha1,
        author         => $actor,
        authored_time  => $time,
        committer      => $actor,
        committed_time => $time,
        comment        => 'import configuration',
    );
    if ($parent) {
        push @commit_attrs, parent => $parent;
    }

    my $commit = Git::PurePerl::NewObject::Commit->new(@commit_attrs);
    $Config::versioned->put_object($commit);

}

sub _hash2tree {
    my $self = shift;
    my $hash = shift;

    if ( ref($hash) ne 'HASH' ) {
        die "ERR: _hash2tree() - arg not hash ref [$hash]";
    }

    my @dir_entries = ();

    foreach my $key ( keys %{$hash} ) {
        if ( ref( $hash->{$key} ) eq 'HASH' ) {
            my $subtree = $self->_hash2tree( $hash->{$key} );
            my $de      = Git::PurePerl::NewDirectoryEntry->new(
                mode     => '40000',
                filename => $key,
                sha1     => $subtree->sha1,
            );
            push @dir_entries, $de;
        }
        else {
            my $obj =
              Git::PurePerl::NewObject::Blob->new( content => $hash->{$key} );
            $Config::versioned->put_object($obj);
            my $de = Git::PurePerl::NewDirectoryEntry->new(
                mode     => '100644',
                filename => $key,
                sha1     => => $obj->sha1,
            );
            push @dir_entries, $de;
        }
    }
    my $tree =
      Git::PurePerl::NewObject::Tree->new(
        directory_entries => [@dir_entries] );
    $Config::versioned->put_object($tree);

    return $tree;
}

=head2 _mknode LOCATION

Creates a node at the given LOCATION, creating parent nodes if necessary.

A reference to the node at the LOCATION is returned.

=cut

sub _mknode {
    my $self     = shift;
    my $location = shift;
    my $ref      = $Config::versioned;
    foreach my $key ( split( /\./, $location ) ) {
        if ( not exists $ref->{$key} ) {
            $ref->{$key} = {};
        }
        elsif ( ref( $ref->{$key} ) ne 'HASH' ) {

            # TODO: fix this ugly error to something more appropriate
            die "Location at $key in $location already assigned to non-HASH";
        }
        $ref = $ref->{$key};
    }
    return $ref;
}

=head2 _findobj LOCATION [, VERSION ]

Returns the Git::PurePerl object found in the file path at LOCATION.

    my $ref1 = $cfg->_findnode("smartcard.ldap.uri");
    my $ref2 = $cfg->_findnode("certs.signature.duration", $wfcfgver);

=cut

sub _findobj {
    my $self     = shift;
    my $location = shift;
    my $ver      = shift;
    my $cfg      = $Config::versioned;

    # If no version hash was given, default to the HEAD of master

    if ( not $ver ) {
        if ( $Config::versioned->all_sha1s->all ) {
            my $master = $Config::versioned->ref('refs/heads/master');
            if ( not $master ) {
                die "ERR: no master object found";
            }
            $ver = $master->sha1;
        }
        else {

            # if no sha1s are in repo, there's nothing to return
            return;
        }

    }

    # TODO: is this the way we want to handle the error of not finding
    # the given object?

    my $obj = $cfg->get_object($ver);
    if ( not $obj ) {
        $@ = "No object found for SHA1 $ver";
        return;
    }

    if ( $obj->kind eq 'commit' ) {
        $obj = $obj->tree;
    }
    my @keys = split /\./, $location;

    # iterate thru the levels in the location

    while (@keys) {
        my $key = shift @keys;

        # $obj should contain the parent tree object.

        my @directory_entries = $obj->directory_entries;

        # find the corresponding child object

        my $found = 0;
        foreach my $de (@directory_entries) {
            if ( $de->filename eq $key ) {
                $found++;
                $obj = $cfg->get_object( $de->sha1 );
                last;
            }
        }

        if ( not $found ) {
            return;
        }
    }
    return $obj;

}

=head2 _get_sect_key LOCATION

Returns the section and key needed by Config::Std to access the
configuration values. The given LOCATION is prepended with the 
current prefix, if set, and is split on the last delimiter. 
The resulting section and key are returned as a list.

=cut

sub _get_sect_key {
    my $self = shift;
    my $key  = shift;
    if ( $self->{prefix} ) {
        $key = $self->{prefix} . $delimiter . $key;
    }

    # Config::Std uses section/key, so we need to split up the
    # given key

    my @tokens = split( /\./, $key );
    $key = pop @tokens;
    my $sect = join( $delimiter, @tokens );

    return $sect, $key;
}

=head2 _read_options()

Called during init(), this method reads the actual configuration values
and populates the internal data structure.

=cut

sub _read_options {
}

=head2 _which( NAME, DIR ... )

Searches the directory list DIR, returning the full path in which the file NAME was
found.

=cut

sub _which {
    my $self = shift;
    my $name = shift;
    my @dirs = @_;

    foreach (@dirs) {
        my $path = $_ . '/' . $name;
        if ( -f $path ) {
            return $path;
        }
    }
    return;
}

=head2 _read_config_path SELF, FILENAME, CFGREF, PATH

Searches for FILENAME in the given directories in PATH. When found,
the file is parsed and a data structure is written to the location
in CFGREF.

Note: this is the wrapper around the underlying libs that read the
configuration data from the files.

=cut

sub _read_config_path {
    my $self    = shift;
    my $cfgname = shift;
    my $cfgref  = shift;

    my $cfgfile = $self->_which( $cfgname, @_ );
    if ( not $cfgfile ) {
        die "ERROR: couldn't find $cfgname in ", join( ', ', @_ );
    }

    read_config( $cfgfile => %{$cfgref} );
}

=head1 ACKNOWLEDGEMENTS

Based on the CPAN module App::Options.

=head1 AUTHOR

Scott T. Hardin, C<< <mrscotty at hnsc.de> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-config-versioned at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Config-Versioned>.
I will be notified, and then you'll automatically be notified of progress
on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Config::Versioned


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Config-Versioned>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Config-Versioned>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Config-Versioned>

=item * Search CPAN

L<http://search.cpan.org/dist/Config-Versioned/>

=back


=head1 COPYRIGHT

Copyright 2011 Scott T. Hardin, all rights reserved.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

1;    # End of Config::Versioned

