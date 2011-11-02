#!/bin/bash
# cPanel, Inc.
# Written by: Brian Oates
# v0.5 09/07/2011

#############
# Functions #
#############
BlackedHours() {
  if [ -f /etc/stats.conf ]
  then
    hours=(`grep "BLACKHOURS=" /etc/stats.conf | sed 's/.*=//' | tr "," "\n"`)
    hourstr=${hours[*]};
    allowed=$((24 - ${#hours[@]}));
    if [ "${#hours[@]}" = 24 ]
    then
      echo -e "${hourstr// /,} (Allowed Time: \033[1;31m0 hours - STATS WILL NEVER RUN!\033[0m)";
    else
      if [ "${#hours[@]}" = 0 ]
      then
        echo -e "Never (Allowed Time: \033[0;32m24 hours\033[0m)";
      else
        echo -e "${hourstr// /,} (Allowed Time: \033[0;32m${allowed} hours\033[0m)";
      fi
    fi
  else
    echo "Never";
  fi
}

RunsEvery() {
  hours=`grep "cycle_hours=" /var/cpanel/cpanel.config | sed 's/.*=//'`
  if [ -z $hours ]
  then
    echo 24;
  else
    echo $hours;
  fi
}

IsAvailable() {
  disabled=`grep "skip${1}=" /var/cpanel/cpanel.config | sed 's/.*=//'`
  if [ "$disabled" = "1" ]
  then
    echo -e "\033[1;31mDisabled\033[0m";
  else
    echo -e "\033[0;32mAvailable\033[0m";
  fi
}

IsDefaultOn() {
  if [ -f /etc/stats.conf ]
  then
    # Make sure we're looking for the stats program in upper case
    prog=`echo ${1} | tr "[:lower:]" "[:upper:]"`
    isdefined=`egrep "DEFAULTGENS=" /etc/stats.conf`
    ison=`egrep "DEFAULTGENS=.*${prog}" /etc/stats.conf`
    if [ -z $isdefined ]
    then
      echo -e "\033[0;32mOn\033[0m";
    else    
      if [ -z $ison ]
      then
        echo -e "\033[1;31mOff\033[0m";
      else
        echo -e "\033[0;32mOn\033[0m";
      fi
    fi
  else
    echo -e "\033[0;32mOn\033[0m";
  fi
}

AllAllowed() {
  if [ -f /etc/stats.conf ]
  then
    allowall=`egrep "ALLOWALL=" /etc/stats.conf | sed 's/.*=//'`
    if [ "$allowall" = "yes" ]
    then
      echo -e "\033[0;32mYes\033[0m";
    else
      echo -e "\033[1;31mNo\033[0m";
    fi
  else
    echo -e "\033[1;31mNo\033[0m";
  fi
}

LogDRunning() {
  check=`/scripts/restartsrv_cpanellogd --check`
  if [[ -z $check ]]
  then
    echo -e "\033[0;32mRunning\033[0m";
  else
    echo -e "\033[1;31mNot Running\033[0m";
  fi
}

KeepingUp() {
  interval=$(($(RunsEvery) * 60));
  oldstats=`find /var/cpanel/lastrun -type f -name 'stats' -mmin +${interval} -exec ls -l {} \;`
  if [[ -z $oldstats ]]
  then
    echo -e "\033[0;32mYes\033[0m";
  else
    echo -e "\033[1;31mNo\033[0m (Run: find /var/cpanel/lastrun -type f -name 'stats' -mmin +${interval} -exec ls -l {} \;)";
  fi
}

UserKeepUp() {
  interval=$(($(RunsEvery) * 60));
  oldstats=`find /var/cpanel/lastrun/${1} -type f -name 'stats' -mmin +${interval} -exec ls -l {} \;`
  if [[ -z $oldstats ]]
  then
    echo -e "\033[0;32mYes\033[0m";
  else
    echo -e "\033[1;31mNo\033[0m";
  fi
}

LastRun() {
  if [ -f /var/cpanel/lastrun/${1}/stats ]; then
    mtime=`stat /var/cpanel/lastrun/${1}/stats | grep 'Modify:' | sed 's/Modify: //' | sed 's/\..*//'`;
    echo $mtime;
  else
    echo "Never";
  fi
}

Awwwwstats() {
  check=`find /usr/local/cpanel/3rdparty/bin/awstats.pl -perm 0755`
  if [ -z $check ]
  then
    echo -e "\033[1;31mAWStats Problem = VERY YES\n/usr/local/cpanel/3rdparty/bin/awstats.pl is not 755 permissions!\033[0m";
  fi
}

HttpdConf() {
  check=`/usr/local/apache/bin/apachectl configtest 2>&1`
  if [[ "$check" =~ "Syntax OK" ]]
  then
    echo -e "\033[0;32mSyntax OK\033[0m";
  else
    echo -e "\033[1;31mSyntax Errors \033[0m(Run: httpd configtest)";
  fi
}

WhoCanPick() {
  if [ -f /etc/stats.conf ]
  then
    users=`grep "VALIDUSERS=" /etc/stats.conf | sed 's/.*=//'`
    if [ -z $users ]
    then
      echo;
    else
      echo $users;
    fi
  else
    echo;
  fi
}

GetEnabledDoms() {
  prog=`echo ${1} | tr "[:lower:]" "[:upper:]"`
  user=$2
  homedir=`grep "${user}" /etc/passwd | cut -d: -f6`
  alldoms=(`egrep "^DNS[0-9]{0,3}=" /var/cpanel/users/${user} | sed 's/DNS[0-9]\{0,3\}=//'`)

  if [ -f $homedir/tmp/stats.conf ]
  then
    for i in "${alldoms[@]}"
    do
      capsdom=`echo ${i} | tr "[:lower:]" "[:upper:]"`
      domsetting=`grep "${prog}-${capsdom}=" ${homedir}/tmp/stats.conf | sed 's/'${prog}'-//' | tr "[:upper:]" "[:lower:]"`
      if [ -z $domsetting ]; then
        echo "$i=\033[1;31mno\033[0m";
      else
        domsetting=${domsetting/=yes/=\\033[0;32myes\\033[0m}
        domsetting=${domsetting/=no/=\\033[1;31mno\\033[0m}
        echo $domsetting;
      fi
    done
  else
    for i in "${alldoms[@]}"
    do
      echo "$i=\033[1;31mno\033[0m";
    done
  fi

}

DumpDomainConfig() {
  prog=$1;
  user=$2;

  doms=$(GetEnabledDoms "$prog" "$user")
  if [[ -z $doms ]]; then
    echo -e "\033[1;31mNO DOMAINS\033[0m :: $prog is available, but not active by default. $user \033[0;32mDOES\033[0m have own privs to enable $prog for domains, but hasn't";
  else
    echo -e "\033[0;32mCAN PICK\033[0m (Per-Domain Config Listed Below)";
    domarray=($doms);
    for i in "${domarray[@]}"
    do
      echo -e "  $i";
    done
  fi
}

WillRunForUser() {
  prog=$1;
  user=$2;

  if [[ $(IsAvailable "$prog") =~ "Disabled" ]]; then
    echo -e "\033[1;31mNO DOMAINS\033[0m :: $prog is disabled server wide";
  else
    if [[ $(IsDefaultOn "$prog") =~ "Off" ]]; then
      if [[ $(AllAllowed) =~ "No" ]]; then
        if [[ $(WhoCanPick) =~ "\<$user\>" ]]; then
          DumpDomainConfig "$prog" "$user";
        else
          echo -e "\033[1;31mNO DOMAINS\033[0m :: $prog is available, but not active by default. $user \033[1;31mDOES NOT\033[0m have privs to enable $prog for domains"; 
        fi
      else
        DumpDomainConfig "$prog" "$user";
      fi
    else
      if [[ $(WhoCanPick) =~ "\<$user\>" ]]; then
        DumpDomainConfig "$prog" "$user";
      else
        echo -e "\033[0;32mALL DOMAINS\033[0m :: $prog is enabled and active by default"
      fi
    fi
  fi
  
}

#####################
# Main Blob of Code #
#####################

# No arg = general info on web stats setup
if [ -z $1 ]
then
  echo -e "\033[36m[ Web Stats Probe Results - v0.5 ]\033[0m";
  echo -e "CPANELLOGD: $(LogDRunning)";
  echo -e "HTTPD CONF: $(HttpdConf)";
  echo -e "BLACKED OUT: $(BlackedHours)";
  echo -e "RUNS EVERY: $(RunsEvery) hours";
  echo -e "KEEPING UP: $(KeepingUp)";
  echo -e "CAN ALL USERS PICK: $(AllAllowed)";
  if [[ $(AllAllowed) =~ "No" ]]; then
    echo -e "WHO CAN PICK STATS: $(WhoCanPick)";
  fi
  echo -e "ANALOG: $(IsAvailable "analog") (Default: $(IsDefaultOn "ANALOG"))";
  echo -e "AWSTATS: $(IsAvailable "awstats") (Default: $(IsDefaultOn "AWSTATS"))";
  echo -e "WEBALIZER: $(IsAvailable "webalizer") (Default: $(IsDefaultOn "WEBALIZER"))";
  Awwwwstats; 
# Otherwise, tell me why that user's stats aren't running
else
  # Check if it's a valid user
  if [ -f /var/cpanel/users/$1 ]
  then
    echo -e "\033[36m[ Stats Configuration For: \033[1;33m$1\033[36m - v0.5 ]\033[0m";
    echo -e "KEEPING UP: $(UserKeepUp "$1") (Last Run: $(LastRun "$1"))";
    echo -e "ANALOG: $(WillRunForUser "analog" "$1")";
    echo -e "AWSTATS: $(WillRunForUser "awstats" "$1")";
    echo -e "WEBALIZER: $(WillRunForUser "webalizer" "$1")";
  else
    echo "ERROR: User [ $1 ] not found";
    echo "Usage: $0 <cP User>";
  fi
fi
echo; 
