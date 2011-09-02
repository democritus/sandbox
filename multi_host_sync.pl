#!/usr/bin/perl

package MultiHostSync;

use 5.010;
use strict;
use warnings;
use YAML::XS;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  $self->{CONFIGURATION} = $self->_configuration_from_file();
  $self->{OPTIONS} = undef;
  $self->{BASE_NAME} = undef;
  $self->{SOURCE_DIRECTORY} = undef;
  bless($self, $class);
  return $self;
}

sub DESTROY {
}

sub configuration {
  my $self = shift;

}

sub _configuration_from_file {
}

my %options;
my %configuration;
my @targets;


sub source_file {
  if ( ! my $fh = open SOURCE_FILE, '<', @_[0] ) {
    die "Cannot open source directory: $!";
  }
  return $fh;
}

sub source_filename {
  return @_[0]
}

sub source_directory_name {
  &source_file
}

sub configuration_from_file {
  return YAML::XS::LoadFile( @_[0] );
}

sub test {
  foreach ( @_ ) {
    print $_ . "\n";
  }
  print @_[0] . "\n";
}

#say &default_options();

sub sync() {
  print sync_command( $configuration{'targets'} );
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
  #return %options;
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

sub target_path {
  my %target = @_[0];
  return %target{'user'} . '@' . %target{'host'} . ':' . %target{'directory'};
}

sub put_command {
  my %target = @_[0];
  return 'rsync ' . &options_list . ' ' . $configuration{'local_directory'} .
    ' ' . &target_path( %target );
}

sub get_command {
  my %target = @_[0];
  return 'rsync ' . &options_list . ' ' . &target_path( %target ) . ' ' .
    $configuration{'local_directory'};
}

sub sync_command {
  my %targets = @_[0];
  my @commands;
  my @actions = ( 'put' );
  foreach( @actions ) {
    my $action = $_;
    foreach( @targets ) {
      @commands.push( eval( $action . '_command', $_ ) );
    }
  }
  @commands.join("; \\\n");
}
