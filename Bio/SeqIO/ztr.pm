# BioPerl module for Bio::SeqIO::ztr
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Aaron Mackey <amackey@virginia.edu>
#
# Copyright Aaron Mackey
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::SeqIO::ztr - ztr trace sequence input/output stream

=head1 SYNOPSIS

Do not use this module directly.  Use it via the Bio::SeqIO class.

=head1 DESCRIPTION

This object can transform Bio::Seq objects to and from ztr trace
files.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 

Please direct usage questions or support issues to the mailing list:

I<bioperl-l@bioperl.org>

rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.
Bug reports can be submitted via the web:

  https://redmine.open-bio.org/projects/bioperl/

=head1 AUTHORS - Aaron Mackey

Email: amackey@virginia.edu

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::SeqIO::ztr;
use vars qw(@ISA $READ_AVAIL);
use strict;

use Bio::SeqIO;
use Bio::Seq::SeqFactory;

push @ISA, qw( Bio::SeqIO );

sub BEGIN {
    eval { require Bio::SeqIO::staden::read; };
    if ($@) {
	$READ_AVAIL = 0;
    } else {
	push @ISA, "Bio::SeqIO::staden::read";
	$READ_AVAIL = 1;
    }
}

sub _initialize {
  my($self,@args) = @_;
  $self->SUPER::_initialize(@args);  
  if( ! defined $self->sequence_factory ) {
      $self->sequence_factory(Bio::Seq::SeqFactory->new(-verbose => $self->verbose(), -type => 'Bio::Seq::Quality'));      
  }

  my ($compression) = $self->_rearrange([qw[COMPRESSION]], @args);
  $compression = 2 unless defined $compression;
  $self->compression($compression);

  unless ($READ_AVAIL) {
      Bio::Root::Root->throw( -class => 'Bio::Root::SystemException',
			      -text  => "Bio::SeqIO::staden::read is not available; make sure the bioperl-ext package has been installed successfully!"
			    );
  }
}

=head2 next_seq

 Title   : next_seq
 Usage   : $seq = $stream->next_seq()
 Function: returns the next sequence in the stream
 Returns : Bio::Seq::Quality object
 Args    : NONE

=cut

sub next_seq {

    my ($self) = @_;

    my ($seq, $id, $desc, $qual) = $self->read_trace($self->_fh, 'ztr');

    # create the seq object
    $seq = $self->sequence_factory->create(-seq        => $seq,
					   -id         => $id,
					   -primary_id => $id,
					   -desc       => $desc,
					   -alphabet   => 'DNA',
					   -qual       => $qual
					   );
    return $seq;
}

=head2 write_seq

 Title   : write_seq
 Usage   : $stream->write_seq(@seq)
 Function: writes the $seq object into the stream
 Returns : 1 for success and 0 for error
 Args    : Bio::Seq object


=cut

sub write_seq {
    my ($self,@seq) = @_;

    my $fh = $self->_fh;
    foreach my $seq (@seq) {
	$self->write_trace($fh, $seq, 'ztr' . $self->compression);
    }

    $self->flush if $self->_flush_on_write && defined $self->_fh;
    return 1;
}

=head2 compression

 Title   : compression
 Usage   : $stream->compression(3);
 Function: determines the level of ZTR compression
 Returns : the current (or newly set) value.
 Args    : 1, 2 or 3 - any other (defined) value will cause the compression
           to be reset to the default of 2.


=cut

sub compression {

    my ($self, $val) = @_;

    if (defined $val) {
	if ($val =~ m/^1|2|3$/o) {
	    $self->{_compression} = $val;
	} else {
	    $self->{_compression} = 2;
	}
    }

    return $self->{_compression};
}

1;
