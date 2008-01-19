#! /usr/bin/perl -w

# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name 'POE-Component-DirWatch';
abstract 'Directory Watcher for POE';
all_from 'lib/POE/Component/DirWatch.pm';

# Specific dependencies
requires 'POE'             => 0.12;
requires 'Moose'           => 0.24;
requires 'Time::HiRes'     => 0;
requires 'Path::Class'     => 0;
requires 'File::Signature' => 0;
requires 'MooseX::Types::Path::Class' => 0;

#recommended (for performance)
recommends 'POE::Component::AIO' => '1.00';

build_requires 'Test::More' => 0;

auto_install;
WriteAll;
