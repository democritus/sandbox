#!/usr/bin/perl

package MultiHostSync;

use 5.010;
use strict;
use warnings;
use File::Basename;
use YAML::XS;
use Data::Dumper;
use Sys::Hostname;

# EXAMPLE
# my $DailySync = MultiHostSync->new( 'daily_sync.yaml' );
# $DailySync->sync();

# Compile-time verified class fields
# http://perldoc.perl.org/fields.html
use fields qw( configuration exclude_patterns files hosts local_directory options );

my %default_options = (
  'compress' => 1,
  'dry_run' => 0,
  'progress' => 1,
  'recursive' => 1,
  'rsh' => '"ssh -p22"',
  'update' => 1,
  'verbose' => 1
);

sub new {
  my $self = shift;
  my $configuration_file = shift;
  # TODO: get options array to permit setting any options from command line
  $self = fields::new($self) unless ref $self;
  # Load YAML into configuration hash
  open my $fh, '<', $configuration_file
    or die "can't open config file: $!";
  my $configuration = YAML::XS::LoadFile( $fh );
  $self->{configuration} = $configuration;
  $self->{exclude_patterns} = $configuration->{'exclude_patterns'};
  $self->{files} = $configuration->{'files'};
  $self->{hosts} = $configuration->{'hosts'};
  $self->{local_directory} = '';
  $self->{options} = $configuration->{'options'};
  # Figure out which of the hosts is the source
  my $current_host = shift || Sys::Hostname::hostname();
  while ( my($key, $value) = each %{$self->{hosts}} ) {
    # Match with current host if matches with nickname or
    # full domain name
    if ( $key eq $current_host || $value->{'domain'} eq $current_host ) {
      $self->{local_directory} = $value->{'directory'};
      delete $self->{hosts}->{$key};
    }
  }
  return $self;
}

sub configuration {
  my $self = shift;
  return $self->{configuration};
}

sub files {
  my $self = shift;
  return $self->{files};
}

sub options {
  my $self = shift;
  my %options = %default_options;
  # Merge options from file with default options
  @options{ keys %{$self->{options}} } = values %{$self->{options}};
  return \%options;
}

sub options_list {
  my $self = shift;
  my @list = ();
  my $options = $self->options;
  while ( my($key, $value) = each %$options ) {
    next unless $value;
    $key = 'dry-run' if $key eq 'dry_run';
    if ( $value ne 0 ) {
      if ( $value ne 1 ) {
        push( @list, '--' . $key . '=' . $value );
      } else {
        push ( @list, '--' . $key );
      }
    }
  }
  return join( ' ', @list );
}

sub hosts {
  my $self = shift @_;
  return $self->{hosts};
}

sub exclude_patterns {
  my $self = shift;
  return $self->{exclude_patterns};
}

sub sync {
  my $self = shift;
  print $self->sync_command . "\n";
}

sub sync_command {
  my $self = shift;
  my @commands = ();
  foreach ( ('put', 'get', 'put') ) {
    my $method = $_ . '_command';
    while ( my($key, $value) = each %{$self->hosts} ) {
      # Necessary?
      # no strict "refs";
      push( @commands, $self->$method( $value ) );
    }
  }
  return join( "; \\\n", @commands );
}

sub local_directory {
  my $self = shift;
  return $self->{local_directory};
}

sub remote_directory {
  my $self = shift;
  my $host = shift;
  return $host->{'user'} . '@' . $host->{'domain'} . ':' . $host->{'directory'};
}

sub get_command {
  my $self = shift;
  my $host = shift;
  return &rsync_command(
    $self->remote_directory($host),
    $self->local_directory,
    $self->files,
    $self->options_list
  ); 
}

sub put_command {
  my $self = shift;
  my $host = shift;
  return &rsync_command(
    $self->local_directory,
    $self->remote_directory($host),
    $self->files,
    $self->options_list
  ); 
}

sub rsync_command {
  my ( $source_directory, $target_directory, $files, $options_list ) = @_;
  my @paths = ();
  foreach ( @$files ) {
    push( @paths, $source_directory . '/' . $_ );
  }
  my $path_list = join( ' ', @paths );
  return 'rsync ' . $options_list . ' ' . $path_list . ' ' . $target_directory;
}

1
