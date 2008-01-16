package POE::Component::DirWatch::Unmodified;

use POE;
use Moose;
use File::Signature;

our $VERSION = "0.001000";

extends 'POE::Component::DirWatch::New';

has modified_interval =>(is => 'rw',isa => 'Num',required => 1,default => 1);

#--------#---------#---------#---------#---------#---------#---------#---------

before '_start' => sub{
    my ($self, $kernel) = @_[OBJECT, KERNEL];
    $kernel->state('modified_check', $self, '_modified_check');
};

override '_file_callback' => sub{
    my ($self, $kernel, $file) = @_[OBJECT, KERNEL, ARG0];
    $kernel->delay(modified_check => $self->modified_interval, $file)
      unless exists $self->signatures->{"$file"};
};

sub _modified_check{
    my ($self, $kernel, $file) = @_[OBJECT, KERNEL, ARG0];
    return unless  $self->signatures->{"$file"}->is_same;
    $self->file_callback->($file);
    delete $self->signatures->{"$file"};
}

1;

__END__;

#--------#---------#---------#---------#---------#---------#---------#---------


=head1 NAME

POE::Component::DirWatch::Unmodified

=head1 SYNOPSIS

  use POE::Component::DirWatch::Unmodified

  my $watcher = POE::Component::DirWatch::Unmodified->new
    (
     alias         => 'dirwatch',
     directory     => '/some_dir',
     filter        => sub { $_[0] =~ /\.gz$/ && -f $_[1] },
     callback      => \&some_sub,
     interval      => 5,
     modified_interval => 2, #pick up untouched files after 2 seconds
    );

  $poe_kernel->run;

=head1 DESCRIPTION

POE::Component::DirWatch::Unmodified extends DirWatch to
exclude files that appear to be in use or are actively being changed.

=head1 Accessors

=head2 stat_interval

Read-Write. An integer value that specifies how many seconds to wait in
between the call to dispatch and the actual dispatch. The interval here serves
as a dead period in between when the initial stat readings are made and the
second reading is made (the one that determines whether there was any change
or not). Note that the C<interval> in C<POE::Component::DirWatch> will be
delayed by this length. See C<_modified_check> for details.

=head2 cmp

An Array::Compare object

=head1 Extended methods

=head2 _start

C<after '_start'> the kernel is called and a new 'stat_check' event is added.

=head2 _file_callback

C<override '_file_callback'> to delay and delegate the execution of the
callback to _modified_check.

=head1 New Methods

=head2 _modified_check

Execute the callback for every file which has not changed since the C<poll>
event.

ARG0 should be the L<Path::Class::File> object for the file in question.

=head2 meta

Keeping tests happy.

=head1 SEE ALSO

L<POE::Component::DirWatch>, L<Moose>

=head1 COPYRIGHT

Copyright 2006 Guillermo Roditi.  All Rights Reserved.  This is
free software; you may redistribute it and/or modify it under the same
terms as Perl itself.

=cut

