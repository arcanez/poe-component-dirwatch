package POE::Component::DirWatch::TouchedFile;

use POE;
use Moose;

our $VERSION = "0.02";

extends 'POE::Component::DirWatch::NewFile';

#--------#---------#---------#---------#---------#---------#---------#---------#

override '_file_callback' => sub{
    my ($self, $kernel, $file) = @_[OBJECT, KERNEL, ARG0];
    return if exists $sigs->{"$file"} && $sigs->{"$file"}->is_same;
    $self->file_callback->($file)
};

1;

__END__;

#--------#---------#---------#---------#---------#---------#---------#---------#


=head1 NAME

POE::Component::DirWatch::TouchedFile

=head1 DESCRIPTION

POE::Component::DirWatch::TouchedFile extends DirWatch::NewFile in order to
exclude files that have already been seen, but still pick up files that have been
changed. Usage is identical to L<POE::Component::DirWatch>.

=head1 METHODS

=head2 _file_callback

C<override '_file_callback'>  Don't call the callback if file has been seen before
and is unchanged.

=head2 meta

See L<Moose>

=head1 SEE ALSO

L<POE::Component::DirWatch::NewFile>, L<POE::Component::DirWatch>

=head1 COPYRIGHT

Copyright 2008 Guillermo Roditi.  All Rights Reserved.  This is
free software; you may redistribute it and/or modify it under the same
terms as Perl itself.

=cut

