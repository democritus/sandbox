#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use File::Basename;
use YAML::XS;

my $configuration = configuration( 'daily_sync.yaml' );
sync( $configuration );

sub sync {
  #my %configuration = shift @_;

  print sync_command( %configuration );
}

sub sync_command {
  #my %configuration = shift @_;

  my @commands = [];
  my @targets = @configuration{'targets'};
  foreach ( [ 'put' ] ) {
    my $action = $_;
    foreach ( @targets ) {
      @commands.push( eval($action_command . '($configuration{"filename"})') );
    }
  }
  @commands.join("; \\\n");
}

sub configuration {
  #my %configuration = shift @_;

  #%default_options = default_options();
  #%options_from_file = YAML::XS::LoadFile( $configuration{'filename'} );
  #return (
  #  %default_options,
  #  %options_from_file,
  #  'filename' => $configuration{'filename'}
  #);
  return (
    default_options(),
    YAML::XS::LoadFile( $configuration{'filename'} ),
    'filename' => $configuration{'filename'}
  );
}

sub source_path {
  my %configuration = shift @_;

  return $configuration{'source_path'};
}

sub base_name {
  my %configuration = shift @_;

  $source_path = source_path( %configuration );
  unless ( open SOURCE_FILE, '<', $source_path ) {
    die "Cannot open source directory: $!";
  }
  return File::Basename::basename( $source_path );
}

sub source_directory {
  my %configuration = shift @_;

  return File::Basename::dirname( source_path( %configuration ) );
}

sub target_path {
  target_directory( shift @_ ) + '/' + base_name();
}

sub target_directory {
  my %target = shift @_;
  $target{'user'} . '@' . $target{'host'} . ':' . $target{'directory'};
}

sub get_command {
  my $target = shift @_;
  #my $options_list = options_list();
  #my $source_path = target_path( $target );
  #my $target_directory = source_directory( $target );
  'rsync ' . options_list() . ' ' . source_path( $target ) . ' ' .
    target_directory( $target );
}

sub put_command {
  my $target = shift @_;
  #my $options_list = options_list();
  #my $target_path = target_path( $target );
  #my $source_directory = source_directory( $target );
  #"rsync $options_list $target_path $source_directory";
  'rsync' . options_list() . ' ' . target_path( $target ) . ' ' .
    source_directory( $target );
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

sub options_list {
  my @list;
  # TODO: merge options from file an default options
  my %options = default_options();
  while ( ($key, $value) = each %options ) {
    if ( $value ) {
      @list.push( '--' . $key . '=' . $value );
    } else {
      @list.push( '--' . $key);
    }
  }
  return @list.join(' ');
}
