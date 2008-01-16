package POE::Component::DirWatch;

our $VERSION = "0.10";

use POE;
use Moose;
use Path::Class::Dir;

#--------#---------#---------#---------#---------#---------#---------#---------#

has directory => (is => 'rw', isa => 'Str', required => 1);
has interval  => (is => 'rw', isa => 'Int', required => 1, default => sub{ 1 });
has alias     => (is => 'rw', isa => 'Str', required => 1, default => 'dirwatch');

has next_poll => (
                  is => 'rw', isa => 'Int',
                  clearer   => 'clear_next_poll',
                  predicate => 'has_next_poll'
                 );

has filter    => (
                  is => 'rw', isa => 'CodeRef',
                  clearer   => 'clear_filter',
                  predicate => 'has_filter'
                 );

has dir_callback  => (
                      is => 'rw', isa => 'Ref',
                      clearer   => 'clear_dir_callback',
                      predicate => 'has_dir_callback'
                     );

has file_callback => (
                      is => 'rw', isa => 'Ref',
                      clearer   => 'clear_file_callback',
                      predicate => 'has_file_callback'
                     );

sub BUILD{
    my ($self, $args) = @_;

    POE::Session->create
          (
           object_states  =>
           [ $self,
             {
              _start   => '_start',
              _pause   => '_pause',
              _resume  => '_resume',
              shutdown => '_shutdown',
              poll     => '_poll',
              ($self->has_dir_callback  ? (dir_callback  => '_dir_callback')  : () ),
              ($self->has_file_callback ? (file_callback => '_file_callback') : () ),
             },
           ]
          );
}

sub session{ $poe_kernel->alias_resolve( shift->alias ) }

#--------#---------#---------#---------#---------#---------#---------#---------#

sub _start{
    my ($self, $kernel) = @_[OBJECT, KERNEL];
    $kernel->alias_set($self->alias); # set alias for ourselves and remember it
    $self->next_poll( $kernel->delay_set(poll => $self->interval) );
}

sub _pause{
    my ($self, $kernel, $until) = @_[OBJECT, KERNEL, ARG0];
    $kernel->alarm_remove($self->next_poll) if $self->has_next_poll;
    $self->clear_next_poll;
    return unless defined $until;

    my $t = time;
    $until += $t if $t > $until;
    $self->next_poll( $kernel->alarm_set(poll => $until) );

}

sub _resume{
    my ($self, $kernel, $when) = @_[OBJECT, KERNEL, ARG0];
    $kernel->alarm_remove($self->next_poll) if $self->has_next_poll;
    $self->clear_next_poll;
    $when = 0 unless defined $when;

    my $t = time;
    $when += $t if $t > $when;
    $self->next_poll( $kernel->alarm_set(poll => $when) );
}

#--------#---------#---------#---------#---------#---------#---------#---------#

sub pause{
    my ($self, $until) = @_;
    $poe_kernel->call($self->alias, _pause => $until);
}

sub resume{
    my ($self, $when) = @_;
    $poe_kernel->call($self->alias, _resume => $when);
}

sub shutdown{
    my ($self) = @_;
    $poe_kernel->alarm_remove($self->next_poll) if $self->has_next_poll;
    $self->clear_next_poll;
    $poe_kernel->post($self->alias, 'shutdown');
}

#--------#---------#---------#---------#---------#---------#---------#---------#

sub _poll {
    my ($self, $kernel) = @_[OBJECT, KERNEL];
    $self->clear_next_poll;
    my $dir = Path::Class::Dir->new($self->directory);
    my $filter = $self->has_filter ? $self->filter : undef;

    while (my $child = $dir->next) {
      next if !$child->is_dir && $child->basename =~ /^\.+$/;
      next if ref $filter && !$filter->($child);

      $child->is_dir ? $kernel->yield(dir_callback => $child)
        : $kernel->yield(file_callback => $child);
    }

    $self->next_poll( $kernel->delay_set(poll => $self->interval) );
}

#these are only here so allow method modifiers to hook into them
#these are prime candidates for inlining when the class is made immutable
sub _file_callback {
    my ($self, $kernel, $file) = @_[OBJECT, KERNEL, ARG0];
    $self->file_callback->($file);
}

sub _dir_callback {
    my ($self, $kernel, $dir) = @_[OBJECT, KERNEL, ARG0];
    $self->dir_callback->($dir);
}

#--------#---------#---------#---------#---------#---------#---------#---------#

sub _shutdown {
    my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
    #cleaup heap, alias, alarms (no lingering refs n ish)
    %$heap = ();
    $kernel->alias_remove($self->alias);
    $kernel->alarm_remove_all();
}

#--------#---------#---------#---------#---------#---------#---------#---------#

1;

__END__;

=head1 NAME

POE::Component::DirWatch::Object - POE directory watcher object

=head1 SYNOPSIS

  use POE::Component::DirWatch::Object;

  #$watcher is a PoCo::DW:Object
  my $watcher = POE::Component::DirWatch::Object->new
    (
     alias      => 'dirwatch',
     directory  => '/some_dir',
     filter     => sub { $_[0] =~ /\.gz$/ && -f $_[1] },
     callback   => \&some_sub,
     # OR
     callback   => [$obj, 'some_sub'], #if you want $obj->some_sub
     interval   => 1,
    );

  $poe_kernel->run;

=head1 DESCRIPTION

POE::Component::DirWatch::Object watches a directory for files. Upon finding
a file it will invoke the user-supplied callback function.

This module was primarily designed as an L<Moose>-based replacement for
 L<POE::Component::Dirwatch>. While all known functionality of the original is
meant to be covered in a similar way there is some subtle differences.

Its primary intended use is processing a "drop-box" style
directory, such as an FTP upload directory.

Apparently the original DirWatch no longer exists. Yes, I know Moose is a bit heavy
but I don't really care. The original is still on BackPAN if you don't like my
awesome replacement.

=head1 Public Methods

=head2 new( \%attrs)

  See SYNOPSIS and Accessors / Attributes below.

=head2 session

Returns a reference to the actual POE session.
Please avoid this unless you are subclassing. Even then it is recommended that
it is always used as C<$watcher-E<gt>session-E<gt>method> because copying the object
reference around could create a problem with lingering references.

=head2 pause [$until]

Synchronous call to _pause. This just posts an immediate _pause event to the kernel.
Safe for use outside of POEish land (doesnt use @_[KERNEL, ARG0...])

=head2 resume [$when]

Synchronous call to _resume. This just posts an immediate _resume event to the kernel.
Safe for use outside of POEish land (doesnt use @_[KERNEL, ARG0...])

=head2 shutdown

Convenience method that posts a FIFO shutdown event.

=head1 Accessors / Attributes

=head2 alias

The alias for the DirWatch session.  Defaults to C<dirwatch> if not
specified. You can NOT rename a session at runtime.

=head2 directory

This is a required argument during C<new>.
The path of the directory to watch.

=head2 interval

The interval waited between the end of a directory poll and the start of another.
 Default to 1 if not specified.

WARNING: This is number NOT the interval between polls. A lengthy blocking callback,
high-loads, or slow applications may delay the time between polls. You can see:
L<http://poe.perl.org/?POE_Cookbook/Recurring_Alarms> for more info.

=head2 callback

This is a required argument during C<new>.
The code to be called when a matching file is found.

The code called will be passed 2 arguments, the $filename and $filepath.
This may take 2 different values. A 2 element arrayref or a single coderef.
When given an arrayref the first item will be treated as an object and the
second as a method name. See the SYNOPSYS.

It usually makes most sense to process the file and remove it from the directory.

    #Example
    callback => sub{ my($filename, $fullpath) = @_ }
    # OR
    callback => [$obj, 'mymethod']

    #Where my method looks like:
    sub mymethod {
        my ($self, $filename, $fullpath) = @_;
    ...

=head2 filter

A reference to a subroutine that will be called for each file
in the watched directory. It should return a TRUE value if
the file qualifies as found, FALSE if the file is to be
ignored.

This subroutine is called with two arguments: the name of the
file, and its full pathname.

If not specified, defaults to C<sub { -f $_[1] }>.

=head2 next_poll

The ID of the alarm for the next scheduled poll, if any. Has clearer
and predicate methods named C<clear_next_poll> and C<has_next_poll>.
Please note that clearing the C<next_poll> just clears the next poll id,
it does not remove the alarm, please use C<pause> for that.

=head1 Private methods

These methods are documented here just in case you subclass. Please
do not call them directly. If you are wondering why some are needed it is so
Moose's C<before> and C<after> work.

=head2 _start

Runs when C<$poe_kernel-E<gt>run> is called. It will create a new DirHandle watching
to C<$watcher-E<gt>directory>, set the session's alias and schedule the first C<poll> event.

=head2 _poll

Triggered by the C<poll> event this is the re-occurring action. _poll will use get a
list of all files in the directory and call C<_aio_callback> with the list of filenames (if any)

I promise I will make this async soon, it's just that IO::AIO doesnt work on FreeBSD.

=head2 _aio_callback

Schedule the next poll and dispatch any files found.

=head2 _dispatch

Triggered by the C<dispatch> event, it recieves a filename in ARG0, it then proceeds to
run the file through the filter and schedule a callback.

=head2 _callback

Triggered by the C<callback> event, it  derefernces the argument list that is passed to
it in ARG0 and calls the appropriate coderef or object-method pair with
$filename and $fullpath in @_;

=head2 _pause [$until]

Triggered by the C<_pause> event this method will remove the alarm scheduling the
next directory poll. It takes an optional argument of $until, which dictates when the
polling should begin again. If $until is an integer smaller than the result of time()
it will treat $until as the number of seconds to wait before polling. If $until is an
integer larger than the result of time() it will treat $until as an epoch timestamp
and schedule the poll alarm accordingly.

     #these two are the same thing
     $watcher->pause( time() + 60);
     $watcher->pause( 60 );

     #this is one also the same
     $watcher->pause;
     $watcher->resume( 60 );


=head2 _resume [$when]

Triggered by the C<_resume> event this method will remove the alarm scheduling the
next directory poll (if any) and schedule a new poll alarm. It takes an optional
argument of $when, which dictates when the polling should begin again. If $when is
an integer smaller than the result of time() it will treat $until as the number of
seconds to wait before polling. If $until is an integer larger than the result of
time() it will treat $when as an epoch timestamp and schedule the poll alarm
accordingly. If not specified, the alarm will be scheduled with a delay of zero.

=head2 _shutdown

Delete the C<heap>, remove the alias we are using and remove all set alarms.

=head2 BUILD

Constructor. C<create()>s a L<POE::Session> and stores it in C<$self-E<gt>session>.

=head2 meta

See L<Moose>

=head1 TODO

=over 4

=item More examples

=item More tests

=back

=head1 SEE ALSO

L<POE::Session>, L<POE::Component>, L<Moose>, L<POE>,

=head1 AUTHOR

Guillermo Roditi, <groditi@cpan.org>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-poe-component-dirwatch at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-DirWatch>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 ACKNOWLEDGEMENTS

=over 4

=item #PoE & #Moose

=item Matt S Trout <mst@shadowcatsystems.co.uk>

=item Rocco Caputo

=item Charles Reiss

=item Stevan Little

=back

=head1 COPYRIGHT

Copyright 2006 Guillermo Roditi.  All Rights Reserved.  This is
free software; you may redistribute it and/or modify it under the same
terms as Perl itself.

=cut
