#!/usr/bin/perl

use MultiHostSync;

my $DailySync = MultiHostSync->new( 'daily_sync.yaml' )
$DailySync->sync();

# mysync = MultiHostSync::new( 'daily_sync.yaml' )
# mysync.sync
