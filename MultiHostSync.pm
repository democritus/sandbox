#!/usr/bin/perl

package MultiHostSync;

use 5.010;
use strict;
use warnings;
use Cwd;
use Data::Dumper;
use File::Basename;
use File::Spec;
use Getopt::Long;
#use Path::Class;
use Sys::Hostname;
use YAML::XS;

use constant PRIVATE_OPTIONS => ( 'hostname' );
use constant KEY_TRANSLATION_MAP => ( 'dry_run' => 'dry-run' );
  
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

sub union {
  my $a = shift;
  my $b = shift;
  my %union;
  foreach my $e ( @$a ) { $union{$e} = 1 }
  foreach my $e ( @$b ) { $union{$e} = 1 }
  my @keys = keys %union;
  return \@keys
}

sub in_array {
  my $array = shift;
  my $element = shift;
  my %is_in_array;
  for ( @$array ) { $is_in_array{$_} = 1 }
  if ( $is_in_array{$element} ) {
    return 1;
  }
  return 0;
}

# Replace underscores with dashes in configuration file since YAML files
# disallow underscores in key names
sub underscores_to_dashes {
  my $input = shift;
   while ( my($key, $value) = each %$input ) {
    if ( $key =~ /_/ ) {
      my $fixed_key = $key;
      $fixed_key =~ s/_/-/;
      $input->{$fixed_key} = $value;
      delete $input->{$key};
    }
  }
  return 1;
}

# Compile-time verified class fields
# http://perldoc.perl.org/fields.html
###use fields qw( CONFIGURATION_FILE USER_OPTIONS );
use fields qw( CONFIGURATION HOSTS LOCAL_HOST );
sub new {
  my $self = shift;
  $self = fields::new($self) unless ref $self;
  my $filename = shift;
###  $self->{CONFIGURATION_FILE} = shift;
  my $cwd = Cwd::cwd();
#  my $path = Path::Class::file( $cwd, $filename );
  my $path = File::Spec->catfile( $cwd, $filename );

  #eval {
    my $configuration = YAML::XS::LoadFile( $path );
  #} or do {
  #  die "can't open configuration file: $!";
  #};

  &underscores_to_dashes( $configuration->{'options'} );
  
  my $hosts = $configuration->{'hosts'};

  my $hostname = $configuration->{'options'}->{'hostname'} ||
    Sys::Hostname::hostname;

  # Remove local host from list of hosts and set it as current host
  my $local_host;
  while ( my($key, $value) = each %$hosts ) {
    $hosts->{$key}->{'protocol'} = 'ssh' unless $value->{'protocol'};
    $hosts->{$key}->{'port'} = 22 unless $value->{'port'};
    if ( $value->{'domain'} eq $hostname ) {
      $local_host = $value;
      delete $hosts->{$key};
    }
  }

  # Restrict command line options and load them into hash
  my %options = ();
  Getopt::Long::GetOptions(
    'compress' => \$options{'compress'},
    'dry-run' => \$options{'dry-run'},
    'exclude=s' => \$options{'exclude'},
    'progress' => \$options{'progress'},
    'recursive' => \$options{'recursive'},
    'rsh=s' => \$options{'rsh'},
    'update' => \$options{'update'},
    'verbose' => \$options{'verbose'}
  );

  # TODO: merge options from config file with command line options
  my @union = ();
  while ( my($key, $value) = each %options ) {
    if ( &is_array($value) && %options ) {
      $options{$key} = &union( \$options{$key}, $value );
    } else {
      $options{$key} = $value;
    }
  }

  $self->{CONFIGURATION} = $configuration;
  $self->{HOSTS} = $hosts;
  $self->{LOCAL_HOST} = $local_host;

  return $self;
}

sub configuration {
  my $self = shift;
  return $self->{CONFIGURATION};
}

sub local_host {
  my $self = shift;
  return $self->{LOCAL_HOST};
}

sub hosts {
  my $self = shift;
  return $self->{HOSTS};
}

sub options {
  my $self = shift;
  return $self->configuration->{'options'};
}

sub files {
  my $self = shift;
  return $self->configuration->{'files'};
}

sub local_directory {
  my $self = shift;
  return $self->local_host->{'directory'};
}

sub local_hostname {
  my $self = shift;
  return $self->local_host->{'domain'};
}

sub options_list {
  my $self = shift;
  my @list = ();
  my $options = $self->options;
  while ( my($key, $value) = each %$options ) {
    next unless $value;

    # Check if key needs to be translated
    my %map = KEY_TRANSLATION_MAP;
    my @keys_to_map = keys %map;
    if ( &in_array(\@keys_to_map, $key) ) {
      $key = $map{$key};
    }
    # In case $value is an array, cycle through each value
    my @instances = ();
    if ( &is_array($value) ) {
      foreach ( @$value ) {
        push( @instances, $_ );
      }
    } else {
      push( @instances, $value );
    }
    foreach ( @instances ) {
      if ( $_ ne 0 ) {
        if ( $_ ne 1 ) {
          push( @list, "--$key=\"$_\"" );
        } else {
          push( @list, '--' . $key );
        }
      }
    }
  }
  return join( ' ', @list );
}

sub sync {
  my $self = shift;
  print $self->sync_command . "\n";
}

sub sync_command {
  my $self = shift;
  my @commands = ();
  my $hosts = $self->hosts;
  #foreach ( ('put', 'get', 'put') ) {
  foreach ( ('put') ) {
    my $method = $_ . '_command';
    while ( my($key, $value) = each %$hosts ) {
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
  return $host->{'user'} . '@' . $host->{'domain'} . ':' .
    $host->{'directory'};
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
