#!/usr/bin/perl

package MultiHostSync;

use 5.010;
use strict;
use warnings;
use Cwd;
use File::Basename;
use YAML::XS;
use Data::Dumper;

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
  my %options = (
    'update' => '',
    'recursive' => '',
    'compress' => '',
    'verbose' => '',
    'progress' => '',
    'rsh' => '"ssh -p22"',
    'dry-run' => '',
  );
  return %options;
}

sub filename {
  my $self = shift @_;
  return $self->{FILENAME};
}

sub configuration {
  my $self = shift @_;
  # Overwrite default options with options from file
  my %default_options = $self->default_options;
  open my $fh, '<', $self->filename
    or die "can't open config file: $!";
  my $configuration = YAML::XS::LoadFile( $fh );
  $configuration{'options'} = $self->default_options();
  Dumper( $configuration );
  return $configuration;
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
  #my %targets = (
  #  'sagan' => {
  #    'user' => 'brianw',
  #    'host' => 'sagan.cpanel.net',
  #    'directory' => '/home/brianw/Documents'
  #  },
  #  'luna' => {
  #    'user' => 'brianw',
  #    'host' => 'sagan.cpanel.net',
  #    'directory' => '/home/brianw/Documents'
  #  },
  #  'lefty' => {
  #    'user' => 'brianw',
  #    'host' => 'sagan.cpanel.net',
  #    'directory' => '/home/brianw/Documents'
  #  }
  #);
  #TODO: why doesn't this work?
  my %targets = $self->targets;
  foreach ( [ 'put' ] ) {
    my $action = $_;
    while ( my($key, $value) = each %targets ) {
      my $command = eval( '$self->' . $action . '_command( $value ) ' );
      push( @commands, $command );
    }
  }
  return @commands.join("; \\\n");
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
  return 'rsync ' . $self->options_list() . ' ' .
    $self->source_path( $target ) . ' ' . $self->target_directory( $target );
}

sub put_command {
  my $self = shift @_;
  my $target = shift @_;
  return 'rsync' . $self->options_list() . ' ' . $self->target_path( $target ) . ' ' . $self->source_directory( $target );
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
