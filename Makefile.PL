use inc::Module::Install;

name     'Config-Versioned';
all_from 'lib/Config/Versioned.pm';
author   'Scott T. Hardin <mrscotty@hnsc.de>';
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

