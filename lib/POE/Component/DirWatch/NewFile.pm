package POE::Component::DirWatch::NewFile;

use POE;
use Moose;
use File::Signature;

our $VERSION = "0.02";

extends 'POE::Component::DirWatch';

has 'signatures' => (is => 'ro', isa => 'HashRef', default => sub{{}});

#--------#---------#---------#---------#---------#---------#---------#---------#

after _file_callback => sub {
  my ($self, $kernel, $file) = @_[OBJECT, KERNEL, ARG0];
  $self->signatures->{ "$file" } ||= File::Signature->new( "$file" );
}

override _file_callback => sub {
    my ($self, $kernel, $file) = @_[OBJECT, KERNEL, ARG0];
    $self->file_callback->($file) unless exists $self->signatures->{"$file"};
};

before _poll => sub{
  my $sigs = shift->signatures;
  delete($sigs->{$_}) for grep {! -e $_ } keys %$sigs;
};

1;

__END__;

#--------#---------#---------#---------#---------#---------#---------#---------#

=head1 NAME

POE::Component::DirWatch::NewFile

=head1 DESCRIPTION

POE::Component::DirWatch::NewFile extends DirWatch to exclude previously seen files

=head1 ATTRIBUTES

=head2 signatures

Read-write. Will return a hashref in which keys will be the full path of the files
seen and the value will be a File::Signature object

=head1 METHODS

=head2 file_callback

C<override '_file_callback'>  Don't call the callback if file has been seen.

C<after '_file_callback'> Add the file's signature to C<signatures> if it doesnt
yet exist.

=head2 _poll

C<before '_poll'> the list of known files is checked and if any of the files no
longer exist they are removed from the list of known files.

=head2 meta

Keeping tests happy.

=head1 SEE ALSO

L<POE::Component::DirWatch>, L<Moose>

=head1 COPYRIGHT

Copyright 2008 Guillermo Roditi.  All Rights Reserved.  This is
free software; you may redistribute it and/or modify it under the same
terms as Perl itself.

=cut

