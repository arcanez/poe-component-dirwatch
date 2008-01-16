package POE::Component::DirWatch::Object::Unmodified;

use POE;
use Moose;
use File::Signature;

our $VERSION = "0.02";

extends 'POE::Component::DirWatch::NewFile';

has modified_interval=> (is => 'rw', isa => 'Num', required => 1, default => 1);

#--------#---------#---------#---------#---------#---------#---------#---------#

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

#--------#---------#---------#---------#---------#---------#---------#---------#


=head1 NAME

POE::Component::DirWatch::Unmodified

=head1 SYNOPSIS

  use POE::Component::DirWatch::Unmodified

  my $watcher = POE::Component::DirWatch::Object::Unmodified->new
    (
     alias         => 'dirwatch',
     directory     => '/some_dir',
     filter        => sub { $_[0] =~ /\.gz$/ && -f $_[1] },
     callback      => \&some_sub,
     interval      => 5,
     stat_interval => 2, #pick up files if they are untouched after 2 seconds
    );

  $poe_kernel->run;

=head1 DESCRIPTION

POE::Component::DirWatch::Unmodified extends DirWatch to
exclude files that appear to be in use or are actively being changed.

=head1 Accessors

=head2 stat_interval

Read-Write. An integer value that specifies how many seconds to wait in between the
call to dispatch and the actual dispatch. The interval here serves as a dead period
in between when the initial stat readings are made and the second reading is made
(the one that determines whether there was any change or not). Note that the
C<interval> in C<POE::Component::DirWatch::Object> will be delayed by this length.
See C<_stat_check> for details.

=head2 cmp

An Array::Compare object

=head1 Extended methods

=head2 _start

C<after '_start'> the kernel is called and a new 'stat_check' event is added.

=head2 _dispatch

C<override '_dispatch'> to delay and delegate the dispatching to _stat_check.
Filtering still happens at this stage.

=head1 New Methods

=head2 _stat_check

Schedule a callback event for every file whose contents have not changed since the
C<poll> event. After all callbacks are scheduled, set an alarm for the next poll.

ARG0 should be the proper params for C<callback> and ARG1 the original C<stat()>
reading we are comparing against.

=head2 meta

Keeping tests happy.

=head1 SEE ALSO

L<POE::Component::DirWatch::Object>, L<Moose>

=head1 AUTHOR

Guillermo Roditi, <groditi@cpan.org>

=head1 BUGS

If a file is created and deleted between polls it will never be seen. Also if a file
is edited more than once in between polls it will never be picked up.

Please report any bugs or feature requests to
C<bug-poe-component-dirwatch-object at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-DirWatch-Object>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Component::DirWatch::Object::Untouched

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-DirWatch-Object>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-DirWatch-Object>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-DirWatch-Object>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Component-DirWatch-Object>

=back

=head1 ACKNOWLEDGEMENTS

People who answered way too many questions from an inquisitive idiot:

=over 4

=item #PoE & #Moose

=item Matt S Trout <mst@shadowcatsystems.co.uk>

=item Rocco Caputo

=back

=head1 COPYRIGHT

Copyright 2006 Guillermo Roditi.  All Rights Reserved.  This is
free software; you may redistribute it and/or modify it under the same
terms as Perl itself.

=cut

