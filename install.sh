#!/usr/bin/env bash
set -e

# Colors
RED="\033[0;31m"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function panic() {
  printf "${RED}ERROR:${NC} %s\n" "$*" >&2
  exit 1
}

# Paths
PWD=$(pwd)
HUB_INSTALL_DIR="${HUB_INSTALL_DIR:-/opt/asic-hub}"
BIN_INSTALL_DIR=/usr/bin
HUB_CONFIG_DIR=/etc/asic-hub
HUB_DATA_DIR=/var/lib/asic-hub
HUB_LOG_DIR=/var/log/asic-hub
SYSTEMD_UNIT_DIR=/etc/systemd/system
HUB_SERVICE_NAME=asic-hub
__FILE=$(basename "$0")


# Distribution files
HUB_BIN=hub
HUBCTL_BIN=hubctl
HUB_UNINSTALL_BIN=uninstall-asic-hub
HUB_CFG=config.toml
HUB_SYSTEMD_UNIT=asic-hub.service
HUB_WWW=public

# Destinations
HUBCTL_SYMLINK="$BIN_INSTALL_DIR/$HUBCTL_BIN"
HUBCTL_SRC="$HUB_INSTALL_DIR/$HUBCTL_BIN"

# Options
SKIP_CONFIRM=false
NO_RESTART=false
NO_ROOT_CHECK=false
SELF_UPDATE=false

function assert_is_root {
  if $NO_ROOT_CHECK; then return 0; fi

  # inline if sometimes terminates install script although user is root.
  if [ ${EUID:-$(id -u)} -ne 0 ]; then panic "you cannot perform this operation unless you are root"; fi
}

function hub_start_service {
  if $NO_RESTART; then
    echo ":: Daemon restart skipped"
    return 0
  fi

#   echo ":: Starting Hub service..."
#   systemctl start $HUB_SERVICE_NAME
#   sleep 1
#   if ! systemctl is-active --quiet $HUB_SERVICE_NAME; then
#     panic "failed to start Hub service, run 'journalctl -u $HUB_SERVICE_NAME' for more info"
#   fi
}

function hub_stop_service {
  if $NO_RESTART; then
    echo ":: Daemon stop skipped"
    return 0
  fi
  echo ':: Stopping Hub service...'
  systemctl stop $HUB_SERVICE_NAME
}

function hub_upgrade {
	if ! $SELF_UPDATE; then
		# shellcheck disable=SC2059
		printf "${YELLOW}Detected existing installation, performing upgrade...${NC}\n"
  fi

  [ -f "$SYSTEMD_UNIT_DIR/$HUB_SYSTEMD_UNIT" ] && hub_stop_service
  echo ':: Copying files...'
  install -v -D $HUB_BIN "$HUB_INSTALL_DIR"
  install -v -D $HUBCTL_BIN "$HUB_INSTALL_DIR"
  [ ! -f "$HUB_INSTALL_DIR/$HUB_UNINSTALL_BIN" ] && install -v -D $HUB_UNINSTALL_BIN "$HUB_INSTALL_DIR"
  [ ! -L $HUBCTL_SYMLINK ] && ln -v -s "$HUBCTL_SRC" $HUBCTL_SYMLINK
  # shellcheck disable=SC2115
  rm -rf "$HUB_INSTALL_DIR/$HUB_WWW"
  cp -rfv $HUB_WWW "$HUB_INSTALL_DIR/$HUB_WWW"

  # Update renamed old DefaultPingInterval config property
  if grep -q StatsCollectInterval "$HUB_CONFIG_DIR/config.toml"; then
    # StatsCollectInterval already exist, delete DefaultPingInterval
    sed -i '/DefaultPingInterval/d' "$HUB_CONFIG_DIR/config.toml"
  else
  	# StatsCollectInterval not exist, rename DefaultPingInterval
  	sed -i 's/DefaultPingInterval/StatsCollectInterval/g' "$HUB_CONFIG_DIR/config.toml"
  fi

	# Update systemd unit
	install -v -m 644 -D $HUB_SYSTEMD_UNIT $SYSTEMD_UNIT_DIR
	systemctl daemon-reload

#   if [ -f "$SYSTEMD_UNIT_DIR/$HUB_SYSTEMD_UNIT" ]; then
#     hub_start_service
#   fi

	if ! $SELF_UPDATE; then
  	# shellcheck disable=SC2059
  	printf "\n${GREEN}[✓]${NC} Hub upgrade completed successfully\n"
  fi
  exit 0
}

function hub_install {
  assert_is_root
  if ! $SKIP_CONFIRM; then
    printf 'Welcome to ASIC Hub installer!\n'
    printf 'This script will install ASIC Hub on this machine.\n\n'
    read -p 'Press [ENTER] to start or [^C] to cancel.' -n 1 -r
    printf '\n\n'
  fi

  # Do upgrade if previous installation exists
  [ -d "$HUB_INSTALL_DIR" ] && hub_upgrade

  echo ":: Creating directories..."
  install -d "$HUB_INSTALL_DIR"
  install -d "$HUB_CONFIG_DIR"
  install -d "$HUB_LOG_DIR"
  install -d "$HUB_DATA_DIR"

  echo ":: Copying files..."
  install -v -D $HUB_BIN "$HUB_INSTALL_DIR"
  install -v -D $HUBCTL_BIN "$HUB_INSTALL_DIR"
  install -v -D $HUB_UNINSTALL_BIN "$HUB_INSTALL_DIR"

  [ ! -L $HUBCTL_SYMLINK ] && ln -v -s "$HUBCTL_SRC" $HUBCTL_SYMLINK
  cp -rfv $HUB_WWW "$HUB_INSTALL_DIR/$HUB_WWW"
  install -v -m 644 -D $HUB_CFG $HUB_CONFIG_DIR
  install -v -m 644 -D $HUB_SYSTEMD_UNIT $SYSTEMD_UNIT_DIR

  # Increase max threads limit if CPU has less or equal 4 cores
  # shellcheck disable=SC2046
  [ $(nproc) -le 4 ] && sed -i 's/\#MaxThreads=[0-9]/MaxThreads=8/g' "$HUB_CONFIG_DIR/$HUB_CFG"

#   echo ":: Registering Hub service..."
#   systemctl enable $HUB_SERVICE_NAME
#   hub_start_service

	if ! $SELF_UPDATE; then
  	# shellcheck disable=SC2059
  	printf "\n${GREEN}[✓]${NC} Installation finished. Open http://localhost:8800 to configure ASIC Hub.\n"
  fi
  exit 0
}

function hub_help {
  echo "$__FILE - ASIC Hub installation script."
  echo ''
  echo "Usage: $__FILE [options]"
  echo ''
  echo 'Options:'
  echo '-y, --yes                Skip confirm prompt'
  echo '-h, --help               Show this help'
  echo '--no-root                No root user check'
  echo '--no-restart             No service restart'
  echo ''
  exit 0
}

while test $# -gt 0; do
  case "$1" in
    -u|--uninstall)
      shift
      panic "Deprecated option, use '$HUB_INSTALL_DIR/$HUB_UNINSTALL_BIN' script to uninstall ASIC Hub."
      ;;
    -y|--yes)
      shift
      SKIP_CONFIRM=true
      ;;
    --no-restart)
      shift
      NO_RESTART=true
      ;;
    --no-root)
      shift
      NO_ROOT_CHECK=true
      ;;
    --hub-self-update)
      shift
      NO_ROOT_CHECK=true
      NO_RESTART=true
      SKIP_CONFIRM=true
      SELF_UPDATE=true
      ;;
    -h|--help)
      shift
      hub_help
      ;;
    *)
      panic "unrecognized option '$1'. See '$(basename "$0") --help' for options"
      break
      ;;
  esac
done

hub_install
