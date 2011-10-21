#!/usr/bin/perl

use MultiHostSync;

my $DailySync = MultiHostSync->new( 'daily_sync.yaml' );
$DailySync->sync();

#test 3
