#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use File::Basename;
use YAML::XS;

sub sync {
  say &sync_command &configuration{'targets'};
}

sub sync_command {
  my @commands = [];
  my @actions = [ 'put' ];
  foreach ( @actions ) {
    my $action = $_;
    foreach ( &targets ) {
      @commands.push( eval("&$action_command", $_) );
    }
  }
  @commands.join("; \\\n");
}

sub configuration {
  $filename = shift @_;
  %configuration_from_file = YAML::LoadFile( $filename );
  return ( %default_options, %configuration_from_file );
}

sub configuration_from_file {
  return YAML::XS::LoadFile( @_[0] );
}

sub source_path {
  return &configuration{ 'source_path' }
}

sub base_name {
  unless ( open SOURCE_FILE, '<', &source_path ) {
    die "Cannot open source directory: $!";
  }
  return File::Basename::basename( &source_path );
}

sub source_directory {
  return File::Basename::dirname( &source_path );
}

sub target_path {
  my %target = shift @_;
  &target_directory( %target ) + '/' + &base_name;
}

sub target_directory {
  my %target = shift @_;
  %target{'user'} . '@' . %target{'host'} . ':' . %target{'directory'};
}

sub get_command {
  "rsync &options_list &source_path &target_directory(target)";
}

sub put_command {
  "rsync &options_list &target_path &source_directory(target)";
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
  while ( ($key, $value) = each %options ) {
    if ( $value ) {
      @list.push( '--' . $key . '=' . $value );
    } else {
      @list.push( '--' . $key);
    }
  }
  return list.join(' ');
}
