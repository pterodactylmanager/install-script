#!/bin/bash
# PterodactylManager installer by DevSky.one noreply@pterodactylmanager.com

# Vars

MACHINE=$(uname -m)
Instversion="1.0"

USE_SYSTEMD=true

# Functions

function greenMessage() {
  echo -e "\\033[32;1m${*}\\033[0m"
}

function magentaMessage() {
  echo -e "\\033[35;1m${*}\\033[0m"
}

function cyanMessage() {
  echo -e "\\033[36;1m${*}\\033[0m"
}

function redMessage() {
  echo -e "\\033[31;1m${*}\\033[0m"
}

function yellowMessage() {
  echo -e "\\033[33;1m${*}\\033[0m"
}

function errorQuit() {
  errorExit 'Exit now!'
}

function errorExit() {
  redMessage "${@}"
  exit 1
}

function errorContinue() {
  redMessage "Invalid option."
  return
}

function makeDir() {
  if [ -n "$1" ] && [ ! -d "$1" ]; then
    mkdir -p "$1"
  fi
}

# Check if the script was run as root user. Otherwise exit the script
if [ "$(id -u)" != "0" ]; then
  errorExit "Change to root account required!"
fi

# Update notify

cyanMessage "Checking for the latest installer version"
if [[ -f /etc/centos-release ]]; then
  yum -y -q install wget
else
  apt-get -qq install wget -y
fi

# Detect if systemctl is available then use systemd as start script. Otherwise use init.d
if [[ $(command -v systemctl) == "" ]]; then
  USE_SYSTEMD=false
fi

# If kernel to old, quit
if [ $(uname -r | cut -c1-1) < 3 ]; then
  errorExit "Linux kernel unsupportet. Update kernel before. Or change hardware."
fi

# If the linux distribution is not debian and centos, then exit
if [ ! -f /etc/debian_version ] && [ ! -f /etc/centos-release ]; then
  errorExit "Not supported linux distribution. Only Debian and CentOS are currently supported"!
fi

greenMessage "This is the automatic installer for latest Pterodactyl with PterodactylManager. USE AT YOUR OWN RISK"!
sleep 1
cyanMessage "You can choose between installing, upgrading and removing the PterodactylManager."
sleep 1
redMessage "Installer by DevSky.one - Coding Support"
sleep 1
yellowMessage "You're using installer $Instversion"

# selection menu if the installer should install, update or remove the PterodactylManager
redMessage "What should the installer do?"
OPTIONS=("Install" "Update" "Remove" "Quit")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
  1 | 2 | 3) break ;;
  4) errorQuit ;;
  *) errorContinue ;;
  esac
done

if [ "$OPTION" == "Install" ]; then
  INSTALL="Inst"
elif [ "$OPTION" == "Update" ]; then
  errorExit "Update not supported yet!"
elif [ "$OPTION" == "Remove" ]; then
  errorExit "Remove not supported yet!"
fi

# Check which OS

if [ "$INSTALL" != "Rem" ]; then

  if [[ -f /etc/centos-release ]]; then
    greenMessage "Installing redhat-lsb! Please wait."
    yum -y -q install redhat-lsb
    greenMessage "Done"!

    yellowMessage "You're running CentOS. Which firewallsystem are you using?"

    OPTIONS=("IPtables" "Firewalld")
    select OPTION in "${OPTIONS[@]}"; do
      case "$REPLY" in
      1 | 2) break ;;
      *) errorContinue ;;
      esac
    done

    if [ "$OPTION" == "IPtables" ]; then
      FIREWALL="ip"
    elif [ "$OPTION" == "Firewalld" ]; then
      FIREWALL="fd"
    fi
  fi

  if [[ -f /etc/debian_version ]]; then
    greenMessage "Check if lsb-release and debconf-utils is installed..."
    apt-get -qq update
    apt-get -qq install debconf-utils -y
    apt-get -qq install lsb-release -y
    greenMessage "Done"!
  fi

  # Functions from lsb_release

  OS=$(lsb_release -i 2>/dev/null | grep 'Distributor' | awk '{print tolower($3)}')
  OSBRANCH=$(lsb_release -c 2>/dev/null | grep 'Codename' | awk '{print $2}')
  OSRELEASE=$(lsb_release -r 2>/dev/null | grep 'Release' | awk '{print $2}')
  VIRTUALIZATION_TYPE=""

  # Extracted from the virt-what sourcecode: http://git.annexia.org/?p=virt-what.git;a=blob_plain;f=virt-what.in;hb=HEAD
  if [[ -f "/.dockerinit" ]]; then
    VIRTUALIZATION_TYPE="docker"
  fi
  if [ -d "/proc/vz" -a ! -d "/proc/bc" ]; then
    VIRTUALIZATION_TYPE="openvz"
  fi

  if [[ $VIRTUALIZATION_TYPE == "openvz" ]]; then
    redMessage "Warning, your server is running OpenVZ! This very old container system isn't well supported by newer packages."
  elif [[ $VIRTUALIZATION_TYPE == "docker" ]]; then
    redMessage "Warning, your server is running in Docker! Maybe there are failures while installing."
  fi

fi

# Go on

if [ "$INSTALL" != "Rem" ]; then
  if [ -z "$OS" ]; then
    errorExit "Error: Could not detect OS. Currently only Debian, Ubuntu and CentOS are supported. Aborting"!
  elif [ -z "$OS" ] && ([ "$(cat /etc/debian_version | awk '{print $1}')" == "7" ] || [ $(cat /etc/debian_version | grep "7.") ]); then
    errorExit "Debian 7 isn't supported anymore"!
  fi

  if [ -z "$OSBRANCH" ] && [ -f /etc/centos-release ]; then
    errorExit "Error: Could not detect branch of OS. Aborting"
  fi

  if [ "$MACHINE" == "x86_64" ]; then
    ARCH="amd64"
  else
    errorExit "$MACHINE is not supported"!
  fi
fi

if [[ "$INSTALL" != "Rem" ]]; then
  if [[ "$USE_SYSTEMD" == true ]]; then
    yellowMessage "Automatically chosen system.d for your startscript"!
  else
    yellowMessage "Automatically chosen init.d for your startscript"!
  fi
fi


# Set path or continue with normal

yellowMessage "Automatic usage or own directories?"

OPTIONS=("Automatic" "Own path" "Quit")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
  1 | 2) break ;;
  3) errorQuit ;;
  *) errorContinue ;;
  esac
done

if [ "$OPTION" == "Automatic" ]; then
  LOCATION=/var/www/pterodactyl
elif [ "$OPTION" == "Own path" ]; then
  yellowMessage "Enter location where the bot should be installed/updated/removed, e.g. /var/www/pterodactyl. Include the / at first position and none at the end"!
  LOCATION=""
  while [[ ! -d $LOCATION ]]; do
    read -rp "Location [/var/www/pterodactyl]: " LOCATION
    if [[ $INSTALL != "Inst" && ! -d $LOCATION ]]; then
      redMessage "Directory not found, try again"!
    fi
    if [ "$INSTALL" == "Inst" ]; then
      if [ "$LOCATION" == "" ]; then
        LOCATION=/var/www/pterodactyl
      fi
      makeDir $LOCATION
    fi
  done

  greenMessage "Your directory is $LOCATION."

  OPTIONS=("Yes" "No, change it" "Quit")
  select OPTION in "${OPTIONS[@]}"; do
    case "$REPLY" in
    1 | 2) break ;;
    3) errorQuit ;;
    *) errorContinue ;;
    esac
  done

  if [ "$OPTION" == "No, change it" ]; then
    LOCATION=""
    while [[ ! -d $LOCATION ]]; do
      read -rp "Location [/var/www/pterodactyl]: " LOCATION
      if [[ $INSTALL != "Inst" && ! -d $LOCATION ]]; then
        redMessage "Directory not found, try again"!
      fi
      if [ "$INSTALL" == "Inst" ]; then
        makeDir $LOCATION
      fi
    done

    greenMessage "Your directory is $LOCATION."
  fi
fi

makeDir $LOCATION


if [[ $INSTALL == "Inst" ]]; then

  if [[ -f $LOCATION ]]; then
    redMessage "Pterodactyl already installed"!
    read -rp "Would you like to update the bot instead? [Y / N]: " OPTION

    if [ "$OPTION" == "Y" ] || [ "$OPTION" == "y" ] || [ "$OPTION" == "" ]; then
      INSTALL="Updt"
    elif [ "$OPTION" == "N" ] || [ "$OPTION" == "n" ]; then
      errorExit "Installer stops now"!
    fi
  else
    greenMessage "Pterodactyl isn't installed yet. Installer goes on."
  fi

elif [ "$INSTALL" == "Rem" ] || [ "$INSTALL" == "Updt" ]; then
  if [ ! -d $LOCATION ]; then
    errorExit "Pterodactyl isn't installed"!
  else
    greenMessage "Pterodactyl is installed. Installer goes on."
  fi
fi

# Update packages or not

redMessage 'Update the system packages to the latest version? (Recommended)'

OPTIONS=("Yes" "No")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
  1 | 2) break ;;
  *) errorContinue ;;
  esac
done

greenMessage "Starting the installer now"!
sleep 2

if [ "$OPTION" == "Yes" ]; then
  greenMessage "Updating the system in a few seconds"!
  sleep 1
  redMessage "This could take a while. Please wait up to 10 minutes"!
  sleep 3

  if [[ -f /etc/centos-release ]]; then
    yum -y -q update
    yum -y -q upgrade
  else
    apt-get -qq update
    apt-get -qq upgrade
  fi
fi

errorExit "Error: PterodactylManager is not public yet."!