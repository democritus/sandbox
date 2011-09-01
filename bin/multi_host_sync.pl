#!/usr/bin/perl

require 'yaml'

sub sync {
  return {
    'update' => nil,
    'recursive' => nil,
    'compress' => nil,
    'verbose' => nil,
    'progress' => nil,
    'rsh' => '"ssh -p22"',
    'dry-run' => nil
  };
}

sub default_options {
}

class MultiHostSync

  attr_accessor :options
  attr_accessor :configuration
#  attr_accessor :targets

  def targets=( input )
    @targets = input
  end

  def targets
    @targets
  end

  def initialize( configuration_file = nil )
    @configuration = configuration_from_file( configuration_file )
    # TODO: allow overriding configuration via command line arguments
    options = {}
    $*.each do |arg|
      pair = arg.split('=')
      options.merge!( pair[0].sub('--', '').to_sym => pair[1] )
    end
    @options = default_options.merge( options )
  end

  def sync
    puts sync_command @configuration['targets']
#    IO.popen( "#{sync_command(@configuration[:targets])}" ) { |f| puts f.gets }
  end

  def default_options
    {
      'update' => nil,
      'recursive' => nil,
      'compress' => nil,
      'verbose' => nil,
      'progress' => nil,
      'rsh' => '"ssh -p22"',
      'dry-run' => nil
    }
  end


  private

  def configuration_from_file( file )
    YAML.load_file file
  end

  def options_list
    @options.map { |key, value|
      "--#{key.to_s}" + (value ? "=#{value}" : '') }.join(' ')
  end

  def target_path( target )
    "#{target['user']}@#{target['host']}:#{target['directory']}"
  end

  def put_command( target )
    "rsync #{options_list} #{@configuration['local_directory']} #{target_path(target)}"
  end

  def get_command( target )
    "rsync #{options_list} #{target_path(target)} #{@configuration['local_directory']}"
  end

  def sync_command( targets )
    commands = []
    [ :put, :get ].each do |type|
      targets.each_pair do |key, target|
        commands << send( "#{type}_command", target )
      end
    end
    commands.join("; \\\n")
  end
end
