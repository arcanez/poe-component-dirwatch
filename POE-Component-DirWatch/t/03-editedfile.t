#!/usr/bin/perl
use strict;

use POE;
use FindBin     qw($Bin);
use File::Path  qw(rmtree);
use Path::Class qw/dir file/;
use Test::More  tests => 7;
use Time::HiRes;
use POE::Component::DirWatch::Modified;

my %FILES = (foo => 2, bar => 1);
my $DIR   = dir($Bin, 'watch');
my $state = 0;
my %seen;

POE::Session->create(
     inline_states =>
     {
      _start   => \&_tstart,
      _stop    => \&_tstop,
      _endtest => sub { $_[KERNEL]->post(dirwatch_test => 'shutdown') }
     },
    );

$poe_kernel->run();
exit 0;

sub _tstart {
  my ($kernel, $heap) = @_[KERNEL, HEAP];

  $kernel->alias_set("CharlieCard");
  # create a test directory with some test files
  File::Path::rmtree("$DIR");
  mkdir("$DIR", 0755) or die "can't create $DIR: $!\n";
  for my $file (keys %FILES) {
    my $path = file($DIR, $file);
    open FH, ">$path" or die "can't create $path: $!\n";
    close FH;
  }

  my $watcher =  POE::Component::DirWatch::Modified->new
    (
     alias      => 'dirwatch_test',
     directory  => $DIR,
     file_callback  => \&file_found,
     interval   => 1,
    );
}

sub _tstop{
  ok(File::Path::rmtree("$DIR"), 'Proper cleanup detected');
}

sub file_found{
  my ($file, $pathname) = @_;
  ok(exists $FILES{$file->basename}, 'correct file');
  ++$seen{$file->basename};

  if(++$state == (keys %FILES) ){
    my $path = file($DIR, 'foo');
    utime time, time, $path;
    ok(1, 'Touching $path');
  } elsif ($state == (keys %FILES) + 1 ) {
    is_deeply(\%FILES, \%seen, 'seen all files');
    ok($seen{foo} == 2," Picked up edited file");
    $poe_kernel->state("endtest",  sub{ $_[KERNEL]->post(CharlieCard => '_endtest') });
    $poe_kernel->delay("endtest", 3);
  } elsif ($state > (keys %FILES) + 1 ) {
    File::Path::rmtree("$DIR");
    die "We seem to be looping, bailing out\n";
    }
}

__END__
