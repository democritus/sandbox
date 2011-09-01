#!/usr/bin/ruby

require 'multi_host_sync'

mysync = MultiHostSync.new( 'daily_sync.yaml' )
mysync.sync
