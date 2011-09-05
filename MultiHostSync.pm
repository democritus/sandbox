#!/usr/bin/perl

package MultiHostSync;

use 5.010;
use strict;
use warnings;
use File::Basename;
use YAML::XS;

# EXAMPLE
# my $DailySync = MultiHostSync->new( 'daily_sync.yaml' )
# $DailySync->sync();

sub new {
  my $type = shift @_;
  my $filename = shift @_;
  my $class = ref($type) || $type;
  my $self  = {};
  $self->{FILENAME} = $filename;
  bless($self, $class);
  return $self;
}

sub DESTROY {
}

sub default_options {
  (
    'update' => '',
    'recursive' => '',
    'compress' => '',
    'verbose' => '',
    'progress' => '',
    'rsh' => '"ssh -p22"',
    'dry-run' => '',
  );
}

sub filename {
  my $self = shift @_;
  return $self->{FILENAME};
}

sub configuration {
  my $self = shift @_;
  # Overwrite default options with options from file
  return (
    $self->default_options(),
    YAML::XS::LoadFile( $self->filename )
  );
}

sub sync {
  my $self = shift @_;
  print sync_command( $self->configuration ) . "\n";
}

sub targets {
  my $self = shift @_;
  return $self->configuration('targets');
}

sub sync_command {
  my $self = shift @_;
  my @commands = [];
  foreach ( [ 'put' ] ) {
    my $action = $_;
    my %targets = $self->targets;
    #foreach ( $self->targets ) {
    while ( my($key, %value) = each %targets ) {
      #my $command = $self->put_command(%_);
      my $command = $self->put_command( %value );
      push( @commands, eval('$self->' . $action . '_command( %value )') );
    }
  }
  @commands.join("; \\\n");
}

sub source_path {
  my $self = shift @_;
  return $self->configuration('source_path');
}

sub base_name {
  my $self = shift @_;
  unless ( open SOURCE_FILE, '<', $self->source_path ) {
    die "Cannot open source path: $!";
  }
  close SOURCE_FILE;
  return File::Basename::basename( $self->source_path );
}

sub source_directory {
  my $self = shift @_;
  return File::Basename::dirname( $self->source_path );
}

sub target_path {
  my $self = shift @_;
  my $target = shift @_;
  return $self->target_directory( $target ) + '/' + $self->base_name;
}

sub target_directory {
  my $self = shift @_;
  my %target = shift @_;
  return $target{'user'} . '@' . $target{'host'} . ':' . $target{'directory'};
}

sub get_command {
  my $self = shift @_;
  my $target = shift @_;
  'rsync ' . $self->options_list() . ' ' . $self->source_path( $target ) . ' ' .
    $self->target_directory( $target );
}

sub put_command {
  my $self = shift @_;
  my $target = shift @_;
  'rsync' . $self->options_list() . ' ' . $self->target_path( $target ) . ' ' .
    $self->source_directory( $target );
}

sub options_list {
  my $self = shift @_;
  my @list = [];
  my %options = $self->default_options;
  # TODO: merge options from file an default options
  while ( my($key, $value) = each %options ) {
    if ( $value ) {
      push( @list, '--' . $key . '=' . $value );
    } else {
      push( @list, '--' . $key );
    }
  }
  return @list.join(' ');
}

1
