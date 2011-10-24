#!/usr/bin/ruby

require 'yaml'

class MultiHostSync

  attr_accessor :options
  attr_accessor :configuration
  attr_accessor :targets

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
    #IO.popen( "#{sync_command(@configuration['targets'])}" ) { |f| puts f.gets }
  end

  def default_options
    {
      'update' => nil,
      'recursive' => nil,
      'compress' => nil,
      'verbose' => nil,
      'progress' => nil,
      'rsh' => '"ssh -p22"'
      #'dry-run' => nil
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

  def source_file
    File.new( @configuration['source_path'] )
  end

  def source_path
    source_file.path
  end

  def base_name
    File.basename( source_path ) 
  end

  def source_directory
    Dir.new( File.dirname( source_path ) )
  end

  def source_directory_path
    source_directory.path
  end

  def target_directory( target )
    "#{target['user']}@#{target['host']}:#{target['directory']}"
  end

  def target_path( target )
    target_directory( target ) + '/' + base_name
  end

  def put_command( target )
    "rsync #{options_list} #{source_path} #{target_directory(target)}"
  end

  def get_command( target )
    "rsync #{options_list} #{target_path(target)} #{source_directory_path}"
  end

  def sync_command( targets )
    commands = []
    # TODO: change to :put, :get, :put to sync files once this is tested
    #[ :put, :get, :put ].each do |type|
    [ :put ].each do |type|
      targets.each_pair do |key, target|
        commands << send( "#{type}_command", target )
      end
    end
    commands.join("; \\\n")
  end
end
