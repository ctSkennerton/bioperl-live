# $Id$
#
# BioPerl module for Bio::TreeIO
#
# Cared for by Jason Stajich <jason@bioperl.org>
#
# Copyright Jason Stajich
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::TreeIO - Parser for Tree files

=head1 SYNOPSIS

  {
      use Bio::TreeIO;
      my $treeio = new Bio::TreeIO('-format' => 'newick',
  				   '-file'   => 'globin.dnd');
      while( my $tree = $treeio->next_tree ) {
  	  print "Tree is ", $tree->size, "\n";
      }
  }

=head1 DESCRIPTION

This is the driver module for Tree reading from data streams and
flatfiles.  This is intended to be able to create Bio::Tree::TreeI
objects.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to
the Bioperl mailing list.  Your participation is much appreciated.

  bioperl-l@bioperl.org              - General discussion
  http://bioperl.org/MailList.shtml  - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
of the bugs and their resolution. Bug reports can be submitted via
email or the web:

  bioperl-bugs@bioperl.org
  http://bioperl.org/bioperl-bugs/

=head1 AUTHOR - Jason Stajich

Email jason@bioperl.org

Describe contact details here

=head1 CONTRIBUTORS

Additional contributors names and emails here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::TreeIO;
use vars qw(@ISA);
use strict;

# Object preamble - inherits from Bio::Root::Root

use Bio::Root::Root;
use Bio::Root::IO;
use Bio::Event::EventGeneratorI;
use Bio::TreeIO::TreeEventBuilder;
use Bio::Factory::TreeFactoryI;

@ISA = qw(Bio::Root::Root Bio::Root::IO 
	Bio::Event::EventGeneratorI Bio::Factory::TreeFactoryI);

=head2 new

 Title   : new
 Usage   : my $obj = new Bio::TreeIO();
 Function: Builds a new Bio::TreeIO object 
 Returns : Bio::TreeIO
 Args    :


=cut

sub new {
  my($caller,@args) = @_;
  my $class = ref($caller) || $caller;
    
    # or do we want to call SUPER on an object if $caller is an
    # object?
    if( $class =~ /Bio::TreeIO::(\S+)/ ) {
	my ($self) = $class->SUPER::new(@args);	
	$self->_initialize(@args);
	return $self;
    } else { 

	my %param = @args;
	@param{ map { lc $_ } keys %param } = values %param; # lowercase keys
	my $format = $param{'-format'} || 
	    $class->_guess_format( $param{'-file'} || $ARGV[0] ) ||
		'newick';
	$format = "\L$format";	# normalize capitalization to lower case

	# normalize capitalization
	return undef unless( &_load_format_module($format) );
	return "Bio::TreeIO::$format"->new(@args);
    }
}


=head2 next_tree

 Title   : next_tree
 Usage   : my $tree = $treeio->next_tree;
 Function: Gets the next tree off the stream
 Returns : Bio::Tree::TreeI or undef if no more trees
 Args    : none

=cut

sub next_tree{
   my ($self) = @_;
   $self->throw("Cannot call method next_tree on Bio::TreeIO object must use a subclass");
}

=head2 write_tree

 Title   : write_tree
 Usage   : $treeio->write_tree($tree);
 Function: Writes a tree onto the stream
 Returns : none
 Args    : Bio::Tree::TreeI


=cut

sub write_tree{
   my ($self,$tree) = @_;
   $self->throw("Cannot call method write_tree on Bio::TreeIO object must use a subclass");
}


=head2 attach_EventHandler

 Title   : attach_EventHandler
 Usage   : $parser->attatch_EventHandler($handler)
 Function: Adds an event handler to listen for events
 Returns : none
 Args    : Bio::Event::EventHandlerI

=cut

sub attach_EventHandler{
    my ($self,$handler) = @_;
    return if( ! $handler );
    if( ! $handler->isa('Bio::Event::EventHandlerI') ) {
	$self->warn("Ignoring request to attatch handler ".ref($handler). ' because it is not a Bio::Event::EventHandlerI');
    }
    $self->{'_handler'} = $handler;
    return;
}

=head2 _eventHandler

 Title   : _eventHandler
 Usage   : private
 Function: Get the EventHandler
 Returns : Bio::Event::EventHandlerI
 Args    : none


=cut

sub _eventHandler{
   my ($self) = @_;
   return $self->{'_handler'};
}

sub _initialize {
    my($self, @args) = @_;
    $self->{'_handler'} = undef;
    
    # initialize the IO part
    $self->_initialize_io(@args);
    $self->attach_EventHandler(new Bio::TreeIO::TreeEventBuilder());
}

=head2 _load_format_module

 Title   : _load_format_module
 Usage   : *INTERNAL TreeIO stuff*
 Function: Loads up (like use) a module at run time on demand
 Example :
 Returns :
 Args    :

=cut

sub _load_format_module {
  my ($format) = @_;
  my ($module, $load, $m);

  $module = "_<Bio/TreeIO/$format.pm";
  $load = "Bio/TreeIO/$format.pm";

  return 1 if $main::{$module};
  eval {
    require $load;
  };
  if ( $@ ) {
    print STDERR <<END;
$load: $format cannot be found
Exception $@
For more information about the TreeIO system please see the TreeIO docs.
This includes ways of checking for formats at compile time, not run time
END
  ;
    return;
  }
  return 1;
}


=head2 _guess_format

 Title   : _guess_format
 Usage   : $obj->_guess_format($filename)
 Function:
 Example :
 Returns : guessed format of filename (lower case)
 Args    :

=cut

sub _guess_format {
   my $class = shift;
   return unless $_ = shift;
   return 'newick'   if /\.(dnd|newick|nh)$/i;
   return 'phyloxml' if /\.(xml)$/i;
}

sub DESTROY {
    my $self = shift;

    $self->close();
}

sub TIEHANDLE {
  my $class = shift;
  return bless {'treeio' => shift},$class;
}

sub READLINE {
  my $self = shift;
  return $self->{'treeio'}->next_tree() unless wantarray;
  my (@list,$obj);
  push @list,$obj  while $obj = $self->{'treeio'}->next_tree();
  return @list;
}

sub PRINT {
  my $self = shift;
  $self->{'treeio'}->write_tree(@_);
}

1;
