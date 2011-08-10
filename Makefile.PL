use inc::Module::Install;

name     'Config-Versioned';
all_from 'lib/Config/Versioned.pm';
author   'Scott T. Hardin <mrscotty@hnsc.de>';
license  'perl';

requires 'Git::PurePerl';

build_requires 'Test::More';
build_requires 'DateTime';
build_requires 'Path::Class';

auto_install;

WriteAll;

