package Bio::DB::GFF::Adaptor::dbi::caching_handle;

use strict;
use DBI;
use Bio::Root::Root;
use vars '$AUTOLOAD','$VERSION','@ISA';
@ISA = qw(Bio::Root::Root);
$VERSION = 1.0;

=head1 NAME

Bio::DB::GFF::Adaptor::dbi::caching_handle -- Cache for database handles

=head1 SYNOPSIS

 use Bio::DB::GFF::Adaptor::dbi::caching_handle;
 $db  = Bio::DB::GFF::Adaptor::dbi::caching_handle->new('dbi:mysql:test');
 $sth = $db->prepare('select * from foo');
 @h   = $sth->fetch_rowarray;
 $sth->finish

=head1 DESCRIPTION

This module handles a pool of database handles.  It was motivated by
the MYSQL driver's {mysql_use_result} attribute, which dramatically
improves query speed and memory usage, but forbids additional query
statements from being evaluated while an existing one is in use.

This module is a plug-in replacement for vanilla DBI.  It
automatically activates the {mysql_use_result} attribute for the mysql
driver, but avoids problems with multiple active statement handlers by
creating new database handles as needed.

=head1 USAGE

The object constructor is
Bio::DB::GFF::Adaptor::dbi::caching_handle-E<gt>new().  This is called
like DBI-E<gt>connect() and takes the same arguments.  The returned object
looks and acts like a conventional database handle.

In addition to all the standard DBI handle methods, this package adds
the following:

=head2 dbi_quote

 Title   : dbi_quote
 Usage   : $string = $db->dbi_quote($sql,@args)
 Function: perform bind variable substitution
 Returns : query string
 Args    : the query string and bind arguments
 Status  : public

This method replaces the bind variable "?" in a SQL statement with
appropriately quoted bind arguments.  It is used internally to handle
drivers that don't support argument binding.

=head2 do_query

 Title   : do_query
 Usage   : $sth = $db->do_query($query,@args)
 Function: perform a DBI query
 Returns : a statement handler
 Args    : query string and list of bind arguments
 Status  : Public

This method performs a DBI prepare() and execute(), returning a
statement handle.  You will typically call fetch() of fetchrow_array()
on the statement handle.  The parsed statement handle is cached for
later use.

=head2 debug

 Title   : debug
 Usage   : $debug = $db->debug([$debug])
 Function: activate debugging messages
 Returns : current state of flag
 Args    : optional new setting of flag
 Status  : public

=cut

sub new {
  my $class    = shift;
  my @dbi_args = @_;
  my $self = bless {
		    dbh    => [],
		    args   => \@dbi_args,
		    debug => 0,
		   },$class;
  $self->dbh || $self->throw("Can't connect to database: " . DBI->errstr);
  $self;
}

sub AUTOLOAD {
  my($pack,$func_name) = $AUTOLOAD=~/(.+)::([^:]+)$/;
  return if $func_name eq 'DESTROY';
  my $self = shift or return DBI->$func_name(@_);
  $self->dbh->$func_name(@_);
}

sub debug {
  my $self = shift;
  my $d = $self->{debug};
  $self->{debug} = shift if @_;
  $d;
}

sub prepare {
  my $self  = shift;
  my $query = shift;

  # find a non-busy dbh
  my $dbh = $self->dbh || $self->throw("Can't connect to database: " . DBI->errstr);
  if (my $sth = $self->{$dbh}{$query}) {
    warn "Using cached statement handler\n" if $self->debug;
    return $sth;
  } else {
    warn "Creating new statement handler\n" if $self->debug;
    $sth = $dbh->prepare($query) || $self->throw("Couldn't prepare query $query:\n ".DBI->errstr."\n");
    return $self->{$dbh}{$query} = $sth;
  }
}

sub do_query {
  my $self = shift;
  my ($query,@args) = @_;
  warn $self->dbi_quote($query,@args),"\n" if $self->debug;
  my $sth = $self->prepare($query);
  $sth->execute(@args) || $self->throw("Couldn't execute query $query:\n ".DBI->errstr."\n");
  $sth;
}

sub dbh {
  my $self = shift;
  foreach (@{$self->{dbh}}) {
    return $_ if $_->inuse == 0;
  }
  # if we get here, we must create a new one
  warn "(Re)connecting to database\n" if $self->debug;
  my $dbh = DBI->connect(@{$self->{args}}) or return;
  my $wrapper = Bio::DB::GFF::Adaptor::dbi::faux_dbh->new($dbh);
  push @{$self->{dbh}},$wrapper;
  $wrapper;
}

sub disconnect {
  my $self = shift;
  $_ && $_->disconnect foreach @{$self->{dbh}};
  $self->{dbh} = [];
}

sub dbi_quote {
  my $self = shift;
  my ($query,@args) = @_;
  my $dbh = $self->dbh;
  $query =~ s/\?/$dbh->quote(shift @args)/eg;
  $query;
}

package Bio::DB::GFF::Adaptor::dbi::faux_dbh;
use vars '$AUTOLOAD';

sub new {
  my $class = shift;
  my $dbh   = shift;
  bless {dbh=>$dbh,usage=>0},$class;
}

sub prepare {
  my $self = shift;
  my $sth = $self->{dbh}->prepare(@_) or return;
  $sth->{mysql_use_result} = 1 if $self->{dbh}->{Driver}{Name} eq 'mysql';
  return Bio::DB::GFF::Adaptor::dbi::faux_sth->new($self,$sth);
}

sub prepare_delayed {
  my $self = shift;
  my $sth = $self->{dbh}->prepare(@_) or return;
  return Bio::DB::GFF::Adaptor::dbi::faux_sth->new($self,$sth);
}

sub inuse {
  $_[0]->{usage};
}

sub increment {
  $_[0]->{usage}++;
}

sub decrement {
  $_[0]->{usage}--;
  $_[0]->{usage} = 0 if $_[0]->{usage} < 0;
}

sub DESTROY { }

sub AUTOLOAD {
  my($pack,$func_name) = $AUTOLOAD=~/(.+)::([^:]+)$/;
  return if $func_name eq 'DESTROY';
  my $self = shift;
  $self->{dbh}->$func_name(@_);
}

package Bio::DB::GFF::Adaptor::dbi::faux_sth;
use vars '$AUTOLOAD';

sub new {
  my $class = shift;
  my ($dbh,$sth) = @_;
  return bless {dbh=>$dbh,sth=>$sth},$class;
}

sub AUTOLOAD {
  my($pack,$func_name) = $AUTOLOAD=~/(.+)::([^:]+)$/;
  return if $func_name eq 'DESTROY';
  my $self = shift;
  $self->{sth}->$func_name(@_);
}

sub execute {
  my $self = shift;
  $self->{dbh}->increment;
  $self->{sth}->execute(@_);
}

sub finish {
  my $self = shift;
  $self->{dbh} && $self->{dbh}->decrement;
  $self->{sth} && $self->{sth}->finish;
}

sub insertid {
  my $self = shift;
  $self->{sth}{mysql_insertid};
}

sub DESTROY {
  my $self = shift;
  $self->finish;
}


1;

__END__

=head1 BUGS

Report to the author.

=head1 SEE ALSO

L<DBI>, L<Bio::DB::GFF>, L<bioperl>

=head1 AUTHOR

Lincoln Stein E<lt>lstein@cshl.orgE<gt>.

Copyright (c) 2001 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

