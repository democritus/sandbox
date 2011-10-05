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

# Testing
my $DailySync = MultiHostSync->new( 'daily_sync.yaml' );

# TODO: I don't really understand this pseudo-hash bullshit
# Store method names in pseudo-hash
my $option_list = 'update recursive compress verbose progress rsh dry-run';
use fields qw( $options );
use vars qw( %FIELDS );
my %default_options;
@default_options{ qw( $option_list ) } = ( 1, 1, 1, 1, 1, '"ssh -p22"', 1 )

sub new {
  my $type = shift @_;
  my $filename = shift @_;
  my $class = ref($type) || $type;
  #my $self  = {};
  #$self->{FILENAME} = $filename;
  my $self = bless [\%FIELDS], $class;

  # Get configuration from filename
  open my $fh, '<', $filename
    or die "can't open config file: $!";
  my $configuration = YAML::XS::LoadFile( $fh );
  my $options = $configuration{ 'options' };

  # TODO: allow overriding options with command line options
  my %initial_options = %default_options;
  @$self{keys %initial_options} = values %initial_options;
  my ($field, $value);
  while ( ($field, $value) = each %arg ) {
    die "Invalid argument: $field"
      unless (exists $FIELDS{"_$field"});
    $self->{"_$field"} = $value;
  }
  bless($self, $class);
  return $self;
}

sub filename {
  my $self = shift @_;
  return $self->{FILENAME};
}

sub sync {
  my $self = shift @_;
  print $self->filename . "\n";
  print $self->sync_command( $self->configuration ) . "\n";
}

sub sync_command {
  my $self = shift @_;
  my @commands = shift @_;
  return @commands.join("; \\\n");
}

sub configuration {
  my $self = shift @_;
  return [ 'command 1', 'command 2', 'command 3' ];
}

#sub sync {
#  my $self = shift @_;
#  print $self->sync_command( $self->configuration ) . "\n";
#}

#sub configuration {
#  my $self = shift @_;
#  # Overwrite default options with options from file
#  my %default_options = $self->default_options;
#  open my $fh, '<', $self->filename
#    or die "can't open config file: $!";
#  my $configuration = YAML::XS::LoadFile( $fh );
#  $configuration->{ 'options' } = $self->default_options();
#  Dumper( $configuration );
#  return $configuration;
#}

#sub targets {
#  my $self = shift @_;
#  Dumper( $self->configuration->{'targets'} );
#  return $self->configuration->{'targets'};
#}

#sub sync_command {
#  my $self = shift @_;
#  my @commands = [];
#  my %targets = $self->targets;
#  foreach ( [ 'put' ] ) {
#    my $action = $_;
#    while ( my($key, $value) = each %targets ) {
#      #my $command = eval( '$self->' . $action . '_command( $value ) ' );
#      my $command = $self->put_command( $value );
#      push( @commands, $command );
#    }
#  }
#  return @commands.join("; \\\n");
#}

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
