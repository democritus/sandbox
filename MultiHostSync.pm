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
# my $DailySync = MultiHostSync->new( 'daily_sync.yaml' );
# $DailySync->sync();

# Compile-time verified class fields
# http://perldoc.perl.org/fields.html
use fields qw( configuration exclude_patterns filename local_directory options targets );

sub new {
  my $self = shift;
  my $filename = shift;
  $self = fields::new($self) unless ref $self;
  # Load YAML into configuration hash
  open my $fh, '<', $filename
    or die "can't open config file: $!";
  my $configuration = YAML::XS::LoadFile( $fh );
  $self->{configuration} = $configuration;
  $self->{exclude_patterns} = @$configuration{'exclude_patterns'};
  $self->{filename} = $filename;
  $self->{local_directory} = @$configuration{'local_directory'};
  $self->{options} = @$configuration{'options'};
  $self->{targets} = @$configuration{'targets'};
  return $self;
}

#sub new {
#  my $type = shift @_;
#  my $filename = shift @_;
#  my $class = ref( $type ) || $type;
#  my $self = {};
#  # Load YAML into configuration hash
#  open my $fh, '<', $filename
#    or die "can't open config file: $!";
#  my $configuration = YAML::XS::LoadFile( $fh );
#  $self->{configuration} = $configuration;
#  $self->{exclude_patterns} = @$configuration{'exclude_patterns'};
#  $self->{filename} = $filename;
#  $self->{local_directory} = @$configuration{'local_directory'};
#  $self->{options} = @$configuration{'options'};
#  $self->{targets} = @$configuration{'targets'};
#  bless( $self, $class );
#  return $self;
#}

sub filename {
  my $self = shift @_;
  return $self->{filename};
}

sub configuration {
  my $self = shift @_;
  return $self->{configuration};
}

sub options {
  my $self = shift @_;
  return $self->{options};
}

sub targets {
  my $self = shift @_;
  return $self->{targets};
}

sub exclude_patterns {
  my $self = shift @_;
  return $self->{exclude_patterns};
}

sub local_directory {
  my $self = shift @_;
  return $self->{local_directory};
}

sub sync {
  my $self = shift @_;
  print $self->filename . "\n";
  print Dumper $self->configuration;
  #print Dumper $self->options;
  #print Dumper $self->targets;
  #print Dumper $self->exclude_patterns;
  #print Dumper $self->local_directory;
  #print $self->sync_command( $self->configuration ) . "\n";
}

sub sync_command {
  my $self = shift @_;
  my $configuration = shift @_;
  my @commands = [];
  my %targets = %{$self->targets};
  foreach ( [ 'put' ] ) {
    #my $action = $_;
    #while ( my($key, $value) = each %targets ) {
    #  #my $command = eval( '$self->' . $action . '_command( $value ) ' );
    #  #my $command = $self->put_command( $value );
    #  push( @commands, $command );
    #}
  }
  return @commands.join("; \\\n");
}

#sub source_path {
#  my $self = shift @_;
#  return $self->configuration('source_path');
#}

#sub base_name {
#  my $self = shift @_;
#  unless ( open SOURCE_FILE, '<', $self->source_path ) {
#    die "Cannot open source path: $!";
#  }
#  close SOURCE_FILE;
#  return File::Basename::basename( $self->source_path );
#}

#sub source_directory {
#  my $self = shift @_;
#  return File::Basename::dirname( $self->source_path );
#}

#sub target_path {
#  my $self = shift @_;
#  my %target = shift @_;
#  return $self->target_directory( %target ) + '/' + $self->base_name;
#}

#sub target_directory {
#  my $self = shift @_;
#  my %target = shift @_;
#  return $target{'user'} . '@' . $target{'host'} . ':' . $target{'directory'};
#}

#sub get_command {
#  my $self = shift @_;
#  my %target = shift @_;
#  return 'rsync ' . $self->options_list() . ' ' .
#    $self->source_path( %target ) . ' ' . $self->target_directory( %target );
#}

#sub put_command {
#  my $self = shift @_;
#  my %target = shift @_;
#  return 'rsync' . $self->options_list() . ' ' . $self->target_path( %target ) .
#    ' ' . $self->source_directory( %target );
#}

#sub options_list {
#  my $self = shift @_;
#  my @list = [];
#  my %options = $self->default_options;
#  # TODO: merge options from file an default options
#  while ( my($key, $value) = each %options ) {
#    if ( $value ) {
#      push( @list, '--' . $key . '=' . $value );
#    } else {
#      push( @list, '--' . $key );
#    }
#  }
#  return @list.join(' ');
#}

1
