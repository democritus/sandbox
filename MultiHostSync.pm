#!/usr/bin/perl

package MultiHostSync;

use 5.010;
use strict;
use warnings;
use File::Basename;
use YAML::XS;
use Data::Dumper;
use Sys::Hostname;
use Getopt::Long;

# EXAMPLE
# my $DailySync = MultiHostSync->new( 'daily_sync.yaml' );
# $DailySync->sync();

sub is_array {
  my ($ref) = @_;
  # Firstly arrays need to be references, throw
  #  out non-references early.
  return 0 unless ref $ref;

  # Now try and eval a bit of code to treat the
  #  reference as an array.  If it complains
  #  in the 'Not an ARRAY reference' then we're
  #  sure it's not an array, otherwise it was.
  eval {
    my $a = @$ref;
  };
  if ($@=~/^Not an ARRAY reference/) {
    return 0;
  } elsif ($@) {
    die "Unexpected error in eval: $@\n";
  } else {
    return 1;
  }
}

# Compile-time verified class fields
# http://perldoc.perl.org/fields.html
use fields qw( CONFIGURATION_FILE USER_OPTIONS );

sub new {
  my $self = shift;
  $self = fields::new($self) unless ref $self;

  $self->{CONFIGURATION_FILE} = shift;

  # Restrict command line options and load them into hash
  my %user_options = ();
  Getopt::Long::GetOptions(
    'compress' => \$user_options{'compress'},
    'dry-run' => \$user_options{'dry-run'},
    'exclude=s' => \$user_options{'exclude'},
    'progress' => \$user_options{'progress'},
    'recursive' => \$user_options{'recursive'},
    'rsh=s' => \$user_options{'rsh'},
    'update' => \$user_options{'update'},
    'verbose' => \$user_options{'verbose'}
  );
  $self->{USER_OPTIONS} = \%user_options;

  return $self;
}

sub default_options {
  # Default options
  my %default_options = (
    'compress' => 1,
    #'dry-run' => 0,
    #'exclude' => 0,
    'progress' => 1,
    'recursive' => 1,
    'rsh' => '"ssh -p22"',
    'update' => 1,
    'verbose' => 1
  );
  return \%default_options;
}

sub user_options {
  my $self = shift;
  return $self->{USER_OPTIONS};
}

sub configuration_file {
  my $self = shift;
  return $self->{CONFIGURATION_FILE};
}

sub configuration_from_file {
  my $file = shift;
  # Get configuration from YAML file and save to hash
  open my $fh, '<', $file or die "can't open config file: $!";
  my $configuration = YAML::XS::LoadFile( $fh );

  # Replace underscores with dashes in configuration file since YAML files
  # disallow underscores in key names
  my $options = $configuration->{'options'}; 
  while ( my($key, $value) = each %$options ) {
    if ( $key =~ /_/ ) {
      my $fixed_key = $key;
      $fixed_key =~ s/_/-/;
      $options->{$fixed_key} = $value;
      delete $options->{$key};
    }
  }
  return $configuration;
}

sub configuration {
  my $self = shift;
  my $default_options = &default_options;
  my $configuration_from_file = &configuration_from_file(
    $self->configuration_file );
  my %configuration = ( 'options' => $default_options );

  # Merge default configuration with keys from configuration file
  @configuration{ keys %$configuration_from_file } =
    values %$configuration_from_file;

  # Override with values from command line
  my $user_options = &user_options;
  my $options = $configuration{'options'};
  while ( my($key, $value) = each %$user_options ) {
    if ( defined $value ) {
      $options->{$key} = $value;
    }
  }
  return \%configuration;
}

sub files {
  my $self = shift;
  return $self->configuration->{'files'};
}

sub options {
  my $self = shift;
  return $self->configuration->{'options'};
}

sub options_list {
  my $self = shift;
  my @list = ();
  my $options = $self->options;
  while ( my($key, $value) = each %$options ) {
    next unless $value;
    # In case $value is an array, cycle through each value
    my @value_instances = ();
    if ( &is_array($value) ) {
      foreach ( @$value ) {
        push( @value_instances, $_ );
      }
    } else {
      push( @value_instances, $value );
    }
    foreach ( @value_instances ) {
      if ( $_ ne 0 ) {
        if ( $_ ne 1 ) {
          push( @list, '--' . $key . '=' . $_ );
        } else {
          push ( @list, '--' . $key );
        }
      }
    }
  }
  return join( ' ', @list );
}

sub remote_hosts {
  my $self = shift;
  my @result = $self->remote_hosts_and_local_directory;
  return $result[0];
}

sub local_directory {
  my $self = shift;
  my @result = $self->remote_hosts_and_local_directory;
  return $result[1];
}

sub remote_hosts_and_local_directory {
  my $self = shift;
  my %hosts = %{ $self->configuration->{'hosts'} };
  my $current_host = Sys::Hostname::hostname();
  my $local_directory = '';
  # Figure out which of the hosts is the source
  while ( my($key, $value) = each %hosts ) {
    # Match with current host if matches domain
    if ( $value->{'domain'} eq $current_host ) {
      $local_directory = $value->{'directory'};
      delete $hosts{$key};
      last;
    }
  }
  return ( \%hosts, $local_directory );
}

sub exclude_patterns {
  my $self = shift;
  return $self->configuration->{'exclude_patterns'};
}

sub sync {
  my $self = shift;
  print $self->sync_command . "\n";
}

sub sync_command {
  my $self = shift;
  my @commands = ();
  my $remote_hosts = $self->remote_hosts;
  foreach ( ('put', 'get', 'put') ) {
    my $method = $_ . '_command';
    while ( my($key, $value) = each %$remote_hosts ) {
      # Necessary?
      # no strict "refs";
      push( @commands, $self->$method( $value ) );
    }
  }
  return join( "; \\\n", @commands );
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
