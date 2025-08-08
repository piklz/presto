#!/usr/bin/env bash
# shellcheck disable=SC1090
#  __/\\\\\\\\\\\\\______/\\\\\\\\\______/\\\\\\\\\\\\\\\_____/\\\\\\\\\\\____/\\\\\\\\\\\\\\\_______/\\\\\______        
#   _\/\\\/////////\\\__/\\\///////\\\___\/\\\///////////____/\\\/////////\\\_\///////\\\/////______/\\\///\\\____       
#    _\/\\\_______\/\\\_\/\\\_____\/\\\___\/\\\______________\//\\\______\///________\/\\\_________/\\\/__\///\\\__      
#     _\/\\\\\\\\\\\\\/__\/\\\\\\\\\\\/____\/\\\\\\\\\\\_______\////\\\_______________\/\\\________/\\\______\//\\\_     
#      _\/\\\/////////____\/\\\//////\\\____\/\\\///////___________\////\\\____________\/\\\_______\/\\\_______\/\\\_    
#       _\/\\\_____________\/\\\____\//\\\___\/\\\_____________________\////\\\_________\/\\\_______\//\\\______/\\\__   
#        _\/\\\_____________\/\\\_____\//\\\__\/\\\______________/\\\______\//\\\________\/\\\________\///\\\__/\\\____  
#         _\/\\\_____________\/\\\______\//\\\_\/\\\\\\\\\\\\\\\_\///\\\\\\\\\\\/_________\/\\\__________\///\\\\\/_____ 
#          _\///______________\///________\///__\///////////////____\///////////___________\///_____________\/////_______

##################################################################################################
#-------------------------------------------------------------------------------------------------
# Welcome to the presto INSTALL/CONFIG FRONTEND 
#--------------------------------------------------------------------------------------------------
# author        : piklz
# github        : https://github.com/piklz/presto.git
# web           : https://github.com/piklz/presto.git
# changes since : v1.1.4, 2025-08-07 (Added LOG_RETENTION_DAYS, CHECK_DISK_SPACE, and updated header)
# desc          : A configuration tool for Raspberry Pi to set up Docker-based media and utility services with robust logging and configuration management
##################################################################################################

presto_VERSION='1.1.5'
INTERACTIVE=True
ASK_TO_REBOOT=0
VERBOSE_MODE=0

# Determine real user's home directory
USER_HOME=""
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    USER="$SUDO_USER"
else
    USER_HOME="$HOME"
    USER="$(id -un)"
fi

# Prevent running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "[presto] ERROR: This script should not be run as root. Run as a regular user or use sudo for specific operations."
    exit 1
fi

# Set log file path
LOG_DIR="$USER_HOME/.local/state/presto"
LOG_FILE="$LOG_DIR/presto_launch.log"
mkdir -p "$LOG_DIR" || { echo "[presto] ERROR: Could not create log directory $LOG_DIR"; exit 1; }
touch "$LOG_FILE" || { echo "[presto] ERROR: Could not create log file $LOG_FILE"; exit 1; }

# Color variables
COL_NC='\e[0m'
COL_LIGHT_GREEN='\e[1;32m'
COL_GREEN='\e[0;32m'
COL_LIGHT_RED='\e[1;31m'
COL_INFO='\e[1;34m'
COL_WARNING='\e[1;33m'
COL_ERROR='\e[1;31m'
TICK="[${COL_LIGHT_GREEN}✓${COL_NC}]"
CROSS="[${COL_LIGHT_RED}✗${COL_NC}]"
INFO="[i]"
DONE="${COL_LIGHT_GREEN} done!${COL_NC}"
OVER="\\r\\033[K"
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
clear='\033[0m'

# Logging function
log_message() {
    local log_level="$1"
    local console_message="$2"
    local log_file_message="${3:-$console_message}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf "[%s] [presto_launch] %s %s\n" "$timestamp" "$log_level" "$log_file_message" >> "$LOG_FILE"
    local color
    case "$log_level" in
        INFO) color="${COL_INFO}" ;;
        WARNING) color="${COL_WARNING}" ;;
        ERROR) color="${COL_ERROR}" ;;
        *) color="${COL_NC}" ;;
    esac
    if [ "$VERBOSE_MODE" -eq 1 ] || [ "$log_level" = "INFO" ] || [ "$log_level" = "WARNING" ] || [ "$log_level" = "ERROR" ]; then
        printf "[presto_launch] %b%s%b %s\n" "$color" "$log_level" "${COL_NC}" "$console_message"
    fi
}

# Rotate logs based on LOG_RETENTION_DAYS
rotate_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        log_message "WARNING" "Log file $LOG_FILE does not exist, skipping rotation"
        return 0
    fi
    if [ -z "$LOG_RETENTION_DAYS" ] || ! [[ "$LOG_RETENTION_DAYS" =~ ^[0-9]+$ ]] || [ "$LOG_RETENTION_DAYS" -le 0 ]; then
        log_message "WARNING" "LOG_RETENTION_DAYS is invalid ($LOG_RETENTION_DAYS), defaulting to 30"
        LOG_RETENTION_DAYS=30
    fi
    log_message "INFO" "Rotating logs older than $LOG_RETENTION_DAYS days in $LOG_FILE"
    # Create a temporary file for filtered logs
    local temp_file="$LOG_DIR/presto_launch_temp.log"
    touch "$temp_file" || { log_message "ERROR" "Failed to create temporary log file $temp_file"; return 1; }
    # Filter out entries older than LOG_RETENTION_DAYS
    local cutoff_date=$(date -d "$LOG_RETENTION_DAYS days ago" '+%Y-%m-%d' 2>/dev/null)
    if [ -z "$cutoff_date" ]; then
        log_message "ERROR" "Failed to calculate cutoff date for log rotation"
        rm -f "$temp_file"
        return 1
    fi
    while IFS= read -r line; do
        log_date=$(echo "$line" | grep -oP '^\[\K[0-9]{4}-[0-9]{2}-[0-9]{2}')
        if [ -z "$log_date" ]; then
            # Keep lines that don't have a valid date (e.g., malformed entries)
            echo "$line" >> "$temp_file"
        elif [ "$log_date" \> "$cutoff_date" ] || [ "$log_date" = "$cutoff_date" ]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$LOG_FILE"
    mv "$temp_file" "$LOG_FILE" || { log_message "ERROR" "Failed to update $LOG_FILE after rotation"; return 1; }
    log_message "INFO" "Log rotation completed"
    return 0
}

# Check disk space before critical operations
check_disk_space() {
    local required_space_mb=1000  # Require 1GB free space
    if [ "$CHECK_DISK_SPACE" -ne 1 ]; then
        log_message "INFO" "Disk space check disabled (CHECK_DISK_SPACE=$CHECK_DISK_SPACE)"
        return 0
    fi
    local available_space_mb
    available_space_mb=$(df -m "$presto_INSTALL_DIR" | tail -1 | awk '{print $4}')
    if [ -z "$available_space_mb" ] || ! [[ "$available_space_mb" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "Failed to determine available disk space"
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "Failed to check disk space. Please ensure sufficient disk space and try again." 20 60 2
        fi
        return 1
    fi
    if [ "$available_space_mb" -lt "$required_space_mb" ]; then
        log_message "ERROR" "Insufficient disk space: $available_space_mb MB available, $required_space_mb MB required"
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "Insufficient disk space: $available_space_mb MB available, $required_space_mb MB required. Please free up space and try again." 20 60 2
        fi
        return 1
    fi
    log_message "INFO" "Disk space check passed: $available_space_mb MB available"
    return 0
}

# Load default configuration
DEFAULT_CONFIG="$USER_HOME/presto-tools/scripts/presto_config.defaults"
if [ ! -f "$DEFAULT_CONFIG" ]; then
    log_message "INFO" "Creating default configuration file $DEFAULT_CONFIG"
    mkdir -p "$USER_HOME/presto-tools/scripts" || { log_message "ERROR" "Failed to create directory for $DEFAULT_CONFIG"; exit 1; }
    cat << EOF > "$DEFAULT_CONFIG"
# Presto default configuration
show_docker_info=1
VERBOSE_MODE=0
log_level="INFO"
LOG_RETENTION_DAYS=30
CHECK_DISK_SPACE=1
EOF
fi
log_message "INFO" "Loading default configuration from $DEFAULT_CONFIG"
source "$DEFAULT_CONFIG"

# Load user configuration to override defaults
CONFIG_FILE="$USER_HOME/presto-tools/scripts/presto_config.local"
if [ -f "$CONFIG_FILE" ]; then
    log_message "INFO" "Overriding defaults with user configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    log_message "WARNING" "User configuration file $CONFIG_FILE not found, using defaults"
fi

# Parse command-line arguments (override config file)
for arg in "$@"; do
    case "$arg" in
        --verbose) VERBOSE_MODE=1 ;;
        *) ;;
    esac
done

# Rotate logs at startup
rotate_logs || { log_message "ERROR" "Log rotation failed, continuing execution"; }

INIT="$(ps --no-headers -o comm 1)"
sys_arch=$(uname -m)
presto_INSTALL_DIR="$USER_HOME/presto"
mkdir -p "$presto_INSTALL_DIR" || { log_message "ERROR" "Could not create $presto_INSTALL_DIR"; exit 1; }
cd "$presto_INSTALL_DIR" || { log_message "ERROR" "Could not enter $presto_INSTALL_DIR"; exit 1; }

# Robust git check and clone
check_git_and_presto() {
    log_message "INFO" "Checking git and presto repository"
    if ! command -v git >/dev/null 2>&1; then
        if [ "$INTERACTIVE" = True ]; then
            whiptail_return=$(whiptail --yesno "Git is not installed. Would you like to install it now?" 20 60 3>&1 1>&2 2>&3; echo $?)
            if [[ $whiptail_return == 0 ]]; then
                log_message "INFO" "Installing git via apt"
                sudo apt update && sudo apt install git -y || { log_message "ERROR" "Failed to install git"; exit 1; }
            else
                log_message "ERROR" "Git is required. Exiting."
                exit 1
            fi
        else
            log_message "ERROR" "Git is required but not installed. Exiting."
            exit 1
        fi
    fi

    if [[ ! -d "$presto_INSTALL_DIR/.git" ]]; then
        if [[ -d "$presto_INSTALL_DIR" ]]; then
            if [[ "$PWD" == "$presto_INSTALL_DIR"* ]]; then
                cd "$USER_HOME" || { log_message "ERROR" "Failed to cd to $USER_HOME"; exit 1; }
            fi
            log_message "INFO" "Removing incomplete or non-git $presto_INSTALL_DIR directory"
            rm -rf "$presto_INSTALL_DIR" || { log_message "ERROR" "Failed to remove $presto_INSTALL_DIR"; exit 1; }
        fi
        log_message "INFO" "Cloning presto repository"
        git clone -b main https://github.com/piklz/presto "$presto_INSTALL_DIR" || { log_message "ERROR" "Failed to clone presto repository"; exit 1; }
    fi

    cd "$presto_INSTALL_DIR" || { log_message "ERROR" "Failed to cd into $presto_INSTALL_DIR"; exit 1; }
    log_message "INFO" "Checking for git updates"
    git fetch origin
    local_status=$(git status --porcelain --branch)
    if [[ $local_status == *"behind"* ]]; then
        log_message "INFO" "Update available for presto repository"
        if [ ! -f .outofdate ] && [ "$INTERACTIVE" = True ]; then
            whiptail --title "Project update" --msgbox "PRESTO update is available (select option 6 to grab update)\nYou will not be reminded again until your next update" 8 78
            touch .outofdate
        fi
    else
        log_message "INFO" "Git repository is up-to-date"
        [ -f .outofdate ] && rm .outofdate
    fi
}

check_git_and_presto

do_update() {
    log_message "INFO" "Updating presto from GitHub"
    check_disk_space || { log_message "ERROR" "Disk space check failed, aborting update"; return 1; }
    git pull origin main || { log_message "ERROR" "Failed to pull latest changes from GitHub"; return 1; }
    find scripts/ -name '*.sh' -type f -exec chmod +x {} + || { log_message "ERROR" "Failed to set execute permissions on scripts"; return 1; }
    [ -f .outofdate ] && rm .outofdate
    log_message "INFO" "Successfully updated presto"
    return 0
}

do_compose_update() {
    log_message "INFO" "Running Docker Compose update"
    if [ -f "${presto_INSTALL_DIR}/scripts/update_compose.sh" ]; then
        bash "${presto_INSTALL_DIR}/scripts/update_compose.sh" || { log_message "ERROR" "Docker Compose update failed"; return 1; }
        log_message "INFO" "Docker Compose update completed"
    else
        log_message "ERROR" "update_compose.sh script not found"
        return 1
    fi
}

timezones() {
    env_file=$1
    TZ=$(cat /etc/timezone 2>/dev/null || echo "UTC")
    log_message "INFO" "Setting timezone in $env_file to $TZ"
    [ $(grep -c "TZ=" "$env_file") -ne 0 ] && sed -i "/TZ=/c\TZ=$TZ" "$env_file" || echo "TZ=$TZ" >> "$env_file"
}

is_pi() {
    ARCH=$(dpkg --print-architecture)
    if [ "$ARCH" = "armhf" ] || [ "$ARCH" = "arm64" ]; then
        return 0
    else
        log_message "WARNING" "Non-Raspberry Pi architecture detected: $ARCH"
        return 1
    fi
}

calc_wt_size() {
    WT_HEIGHT=18
    WT_WIDTH=$(tput cols)
    [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ] && WT_WIDTH=80
    [ "$WT_WIDTH" -gt 178 ] && WT_WIDTH=120
    WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}

do_finish() {
    if [ $ASK_TO_REBOOT -eq 1 ] && [ "$INTERACTIVE" = True ]; then
        if whiptail --yesno "Would you like to reboot now?" 20 60 2; then
            log_message "INFO" "Initiating system reboot"
            sync
            sudo reboot now
        fi
    fi
    log_message "INFO" "Exiting presto_launch.sh"
    exit 0
}

# Container array and keys unchanged
declare -A cont_array=(
    [portainer]="Portainer > GUI Docker Manager"
    [sonarr]="Sonarr > for your Tv "
    [radarr]="Radarr > for your film "
    [lidarr]="Lidarr > for your music "
    [jackett]="Jackett > indexer of torrents for radarr/sonar/*arr etc"
    [qbittorrent]="qBittorrent > Torrent Client"
    [jellyfin]="JellyFin > Media manager/player like plex but freee"
    [plex]="Plex > Media manager/player nice UI not free"
    [tautulli]="tautulli > plex stats grapher"
    [overseerr]="overseerr > plex movie/tv requester nice ui"
    [heimdall]="heimdall > Nice frontend dashboard for all your *arr apps "
    [homeassistant]="Home-Assistant > automate home devices ,hue,lifx,google"
    [motioneye]="motioneye > free security cam"
    [homarr]="Homarr > like heimdall-Nice frontend dashboard !try this first?"
    [wireguard]="Wireguard > your own fast free vpn"
    [pihole]="pi-hole > adblocker!"
    [wgui]="Wireguard-UI > web portal for wireguard vpn config"
    [uptimekuma]="uptime-kuma all your base system health monitor"
    [syncthing]="Syncthing > the sync tools you always wanted webui easy to use "
    [photoprism]="Photoprism > your own google photos ! with ai-tensor for tagging "
    [glances]="Glances > An eye on your system"
    [prowlarr]="Prowlarr > Prowlarr supports both Torrent Trackers and Usenet Indexers."
    [homepage]="Homepage > customizable application dashboard"
    [ittools]="it-tools > nice IT. tools in one place "
)

declare -a aarch64_keys=(
    "portainer" "sonarr" "radarr" "lidarr" "jackett" "qbittorrent" "jellyfin" "plex" "tautulli" "overseerr"
    "heimdall" "homeassistant" "motioneye" "homarr" "wireguard" "pihole" "wgui" "uptimekuma" "syncthing"
    "photoprism" "glances" "prowlarr" "homepage" "ittools"
)

yml_builder() {
    service="services/$1/service.yml"
    [ -d ./services/ ] || mkdir ./services/ || { log_message "ERROR" "Failed to create services directory"; return 1; }

    if [ -d "./services/$1" ]; then
        if [ "$INTERACTIVE" = True ]; then
            service_overwrite=$(whiptail --radiolist --title "Deployment Option" --notags \
                "$1 was already created before, use [SPACEBAR] to select redeployment configuration" 20 78 12 \
                "none" "Use recent config" "ON" \
                "env" "Preserve Environment and Config files" "OFF" \
                "full" "Pull config from template" "OFF" \
                3>&1 1>&2 2>&3)
        else
            service_overwrite="none"
        fi

        case $service_overwrite in
            "full")
                log_message "INFO" "Pulling full $1 from template"
                rsync -a -q .templates/$1/ services/$1/ --exclude 'build.sh' || { log_message "ERROR" "Failed to rsync full template for $1"; return 1; }
                ;;
            "env")
                log_message "INFO" "Pulling $1 from template excluding env/conf files"
                rsync -a -q .templates/$1/ services/$1/ --exclude 'build.sh' --exclude '$1.env' --exclude '*.conf' || { log_message "ERROR" "Failed to rsync template for $1"; return 1; }
                ;;
            "none")
                log_message "INFO" "$1 service files not overwritten"
                ;;
        esac
    else
        mkdir ./services/$1 || { log_message "ERROR" "Failed to create service directory for $1"; return 1; }
        log_message "INFO" "Pulled full $1 from template directory"
        rsync -a -q .templates/$1/ services/$1/ --exclude 'build.sh' || { log_message "ERROR" "Failed to rsync template for $1"; return 1; }
    fi

    [ -f "./services/$1/$1.env" ] && timezones "./services/$1/$1.env"
    echo "" >> docker-compose.yml
    if ! grep -q "services:$1:" docker-compose.yml && [[ "${containers[@]}" =~ "$1" ]]; then
        cat "$service" >> docker-compose.yml || { log_message "ERROR" "Failed to append $service to docker-compose.yml"; return 1; }
    fi
}

do_bash_aliases() {

    if [ -f "$USER_HOME/presto-tools/scripts/presto-tools_install.sh" ]; then
            if [ "$INTERACTIVE" = True ]; then
                log_message "INFO" "Created presto bash aliases in $USER_HOME/presto-tools/scripts/.presto_bash_aliases"
                echo "Setting up bash aliases using presto-tools..."
                bash "$USER_HOME/presto-tools/scripts/presto-tools_install.sh" --setup-bash-aliases --include-presto
                whiptail --msgbox "CREATED presto bash_aliases. presto_up,presto_down,presto_start,presto_stop,presto_update,presto_build,presto_status,cpv,presto_upgrade-pi-sys,presto_dusummary,presto_status_usage,presto_status_usage2 & more!" 20 80 2
            fi
            
        else
            log_message "WARN" "Presto-tools not found no aliases added"
            if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "Presto-tools not found. Please install presto-tools to set up aliases." 8 60
            fi
    fi

    source "$USER_HOME/.bashrc" || log_message "WARNING" "Failed to source .bashrc"
    ASK_TO_REBOOT=1
    log_message "INFO" "Presto aliases will be ready after a reboot/logout"
    if [ "$INTERACTIVE" = True ]; then
        whiptail --msgbox "Presto aliases will be ready after a reboot" 20 60 2
    fi


}



do_start_stack() {
    if [ -f "${presto_INSTALL_DIR}/scripts/start.sh" ]; then
        source "${presto_INSTALL_DIR}/scripts/start.sh" || { log_message "ERROR" "Failed to execute start.sh"; return 1; }
        log_message "INFO" "Docker start script completed"
        sleep 3
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "Presto docker stack started" 20 60 2
        fi
    else
        log_message "ERROR" "start.sh script not found"
        return 1
    fi
}

do_stop_stack() {
    if [ -f "${presto_INSTALL_DIR}/scripts/stop.sh" ]; then
        source "${presto_INSTALL_DIR}/scripts/stop.sh" || { log_message "ERROR" "Failed to execute stop.sh"; return 1; }
        log_message "INFO" "Docker stop script completed"
        sleep 3
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "Presto docker stacks stopped" 20 60 2
        fi
    else
        log_message "ERROR" "stop.sh script not found"
        return 1
    fi
}

do_update_stack() {
    check_disk_space || { log_message "ERROR" "Disk space check failed, aborting stack update"; return 1; }
    if [ -f "${presto_INSTALL_DIR}/scripts/update.sh" ]; then
        source "${presto_INSTALL_DIR}/scripts/update.sh" || { log_message "ERROR" "Failed to execute update.sh"; return 1; }
        log_message "INFO" "Docker update stack script completed"
        sleep 3
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "Presto docker update stacks started" 20 60 2
        fi
    else
        log_message "ERROR" "update.sh script not found"
        return 1
    fi
}

do_restart_stack() {
    if [ -f "${presto_INSTALL_DIR}/scripts/restart.sh" ]; then
        source "${presto_INSTALL_DIR}/scripts/restart.sh" || { log_message "ERROR" "Failed to execute restart.sh"; return 1; }
        log_message "INFO" "Docker restart script completed"
        sleep 3
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "Presto docker stacks restarted" 20 60 2
        fi
    else
        log_message "ERROR" "restart.sh script not found"
        return 1
    fi
}

do_prune_volumes_stack() {
    if [ -f "${presto_INSTALL_DIR}/scripts/prune-volumes.sh" ]; then
        source "${presto_INSTALL_DIR}/scripts/prune-volumes.sh" || { log_message "ERROR" "Failed to execute prune-volumes.sh"; return 1; }
        log_message "INFO" "Docker prune volumes script completed"
        sleep 3
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "Presto docker prune volume stacks completed" 20 60 2
        fi
    else
        log_message "ERROR" "prune-volumes.sh script not found"
        return 1
    fi
}

do_prune_images_stack() {
    if [ -f "${presto_INSTALL_DIR}/scripts/prune-images.sh" ]; then
        source "${presto_INSTALL_DIR}/scripts/prune-images.sh" || { log_message "ERROR" "Failed to execute prune-images.sh"; return 1; }
        log_message "INFO" "Docker prune images script completed"
        sleep 3
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "Presto docker prune images stacks completed" 20 60 2
        fi
    else
        log_message "ERROR" "prune-images.sh script not found"
        return 1
    fi
}

do_install_docker_menu() {
    if is_pi; then
        FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "System Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
            "S1 Install DOCKER|COMPOSE(REQUIRED)" "Installs main base system: Docker + Docker Compose" \
            "S2 Build Stack" "Use the [SPACEBAR] to select which containers you would like to use" \
            "S3 Install presto Bash Welcome" "creates link to bash script added info for '$USER' user" \
            3>&1 1>&2 2>&3)
    fi
    RET=$?
    if [ $RET -eq 1 ]; then
        return 0
    elif [ $RET -eq 0 ]; then
        case "$FUN" in
            S1\ *) do_dockersystem_install ;;
            S2\ *) do_build_stack_menu ;;
            S3\ *) do_install_prestobashwelcome ;;
            *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
        esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
    fi
}

do_dockersystem_install() {
    log_message "INFO" "Installing Docker and Docker Compose (requires sudo)"
    if [ ! -n "$SUDO_USER" ]; then
        log_message "WARNING" "Docker installation requires sudo. Please run with sudo for this operation."
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "Docker installation requires sudo. Please run 'sudo ./presto_launch.sh' for this option." 20 60 2
        fi
        return 1
    fi
    sudo apt-get update -y || { log_message "ERROR" "Failed to update apt"; return 1; }
    sudo apt-get install ca-certificates curl gnupg -y || { log_message "ERROR" "Failed to install prerequisites"; return 1; }
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg || { log_message "ERROR" "Failed to add Docker GPG key"; return 1; }
    sudo chmod a+r /etc/apt/keyrings/docker.gpg -y
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || { log_message "ERROR" "Failed to add Docker repository"; return 1; }
    sudo apt-get update || { log_message "ERROR" "Failed to update apt after adding Docker repo"; return 1; }
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y || { log_message "ERROR" "Failed to install Docker components"; return 1; }
    
    log_message "INFO" "Adding group user docker"
    sudo groupadd docker 2>/dev/null || log_message "WARNING" "Docker group already exists"
    log_message "INFO" "Adding $USER to docker group"
    sudo usermod -aG docker "$USER" &> /dev/null || { log_message "ERROR" "Failed to add $USER to docker group"; return 1; }
    log_message "INFO" "Docker installed successfully for $USER"
    
    ASK_TO_REBOOT=1
    if [ "$INTERACTIVE" = True ]; then
        whiptail --msgbox "PRESTO recommends a reboot now\n" 20 60 2
    fi
    log_message "INFO" "Docker installation complete, reboot recommended"
    do_finish
}

do_build_stack_menu() {
    check_disk_space || { log_message "ERROR" "Disk space check failed, aborting build"; return 1; }
    title="Container Selection"
    message="Use the [SPACEBAR] to select which containers you would like to use then tab for OK|skip"
    entry_options=()

    if [ $(echo "$sys_arch" | grep -c "arm") ]; then
        keylist=("${aarch64_keys[@]}")
    else
        log_message "ERROR" "Architecture $sys_arch not supported"
        exit 1
    fi

    for index in "${keylist[@]}"; do
        entry_options+=("$index" "${cont_array[$index]}")
        if [ -f ./services/selection.txt ] && grep -q "$index" ./services/selection.txt; then
            entry_options+=("ON")
        else
            entry_options+=("OFF")
        fi
    done

    container_selection=$(whiptail --title "$title" --notags --separate-output --checklist \
        "$message" 20 78 12 -- "${entry_options[@]}" 3>&1 1>&2 2>&3)

    mapfile -t containers <<<"$container_selection"

    if [ -n "$container_selection" ]; then
        touch docker-compose.yml
        log_message "INFO" "Creating docker-compose.yml"
        cat << EOF > docker-compose.yml
networks:
  private_network:
    name: "pihole-dns"
    driver: bridge
    ipam:
      config:
        - subnet: 172.19.0.0/24 #prestos internal docker network pihole to wireguard etc
services:
EOF

        [ -f ./services/selection.txt ] && rm ./services/selection.txt
        [ -d ./services ] || mkdir services
        touch ./services/selection.txt

        for container in "${containers[@]}"; do
            log_message "INFO" "Adding $container container"
            yml_builder "$container"
            echo "$container" >> ./services/selection.txt
        done

        if [ -f ./services/custom.txt ]; then
            if [ "$INTERACTIVE" = True ] && whiptail --title "Custom Container detected" --yesno "custom.txt has been detected do you want to add these containers to the stack?" 20 78; then
                mapfile -t containers <<<$(cat ./services/custom.txt)
                for container in "${containers[@]}"; do
                    log_message "INFO" "Adding custom $container container"
                    yml_builder "$container"
                done
            fi
        fi

        log_message "INFO" "docker-compose.yml successfully created"
        echo -e "run \e[104;1mdocker-compose up -d or 'presto_up'\e[0m to start the stack"
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "[presto] Build Stack FINISHED !RUN 'docker-compose up -d' or 'presto_up' to start the stack in terminal" 20 60 2
        fi
    else
        log_message "INFO" "Build cancelled"
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "Presto build stack cancelled" 20 60 2
        fi
    fi
}

do_rclone_install() {
    if [[ -f /usr/bin/rclone ]] && rclone listremotes | grep -q 'gdrive:'; then
        log_message "INFO" "rclone installed and gdrive configured"
        echo -e "\e[32m=====================================================================================\e[0m"
        echo -e "\e[36;1m    rclone installed and gdrive configured, go to Backup or Restore \e[0m"
        echo -e "\e[32m=====================================================================================\e[0m"
    else
        log_message "INFO" "Installing rclone (requires sudo)"
        if [ ! -n "$SUDO_USER" ]; then
            log_message "WARNING" "rclone installation requires sudo. Please run with sudo for this operation."
            if [ "$INTERACTIVE" = True ]; then
                whiptail --msgbox "rclone installation requires sudo. Please run 'sudo ./presto_launch.sh' for this option." 20 60 2
            fi
            return 1
        fi
        sudo -v ; curl https://rclone.org/install.sh | sudo bash || { log_message "ERROR" "Failed to install rclone"; return 1; }
        log_message "INFO" "rclone installation complete, configuring gdrive"
        echo -e "\e[32m=====================================================================================\e[0m"
        echo -e "     Please run \e[32;1mrclone config\e[0m and create remote \e[34;1m(gdrive)\e[0m for backup"
        echo -e "     Do as follows:"
        echo -e "      [n] ['gdrive'] [12 or 23 or more recent versions are 18) make sure its 'drive'] [Enter] [Enter] [1] [Enter] [Enter] [n] [n]"
        echo -e "      [Copy link from SSH console and paste it into the browser]"
        echo -e "      [Login to your google account]"
        echo -e "      [Copy token from Google and paste it into the SSH console]"
        echo -e "      [n] [y] [q]"
        echo -e "\e[32m=====================================================================================\e[0m"
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "\
Please run rclone config and create remote (gdrive) for backup

Do steps in terminal follows:
[n] [gdrive] [12 or 13 or 18 make sure its 'drive'] [Enter] [Enter] [1] [Enter] [Enter] [n] [n]
[Copy link from SSH console and paste it into the browser]
[Login to your google account]
[Copy token from Google and paste it into the SSH console]
[n] [y] [q]
" 20 100 1
        fi
    fi
}

do_backup_gdrive() {
    if [ -f "${presto_INSTALL_DIR}/scripts/rclone_backup.sh" ]; then
        source "${presto_INSTALL_DIR}/scripts/rclone_backup.sh" || { log_message "ERROR" "Failed to execute rclone_backup.sh"; return 1; }
        log_message "INFO" "Backup to Google Drive completed"
    else
        log_message "ERROR" "rclone_backup.sh script not found"
        return 1
    fi
}

do_restore_gdrive() {
    if [ -f "${presto_INSTALL_DIR}/scripts/rclone_restore.sh" ]; then
        source "${presto_INSTALL_DIR}/scripts/rclone_restore.sh" || { log_message "ERROR" "Failed to execute rclone_restore.sh"; return 1; }
        log_message "INFO" "Restore from Google Drive completed"
    else
        log_message "ERROR" "rclone_restore.sh script not found"
        return 1
    fi
}

do_dockercommands_menu() {
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (presto-config)" --menu "Performance Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
        "P1 Add presto-tools docker aliases" "set useful bash cmd aliases" \
        "P2 Docker Start" "runs Docker start.sh in /scripts" \
        "P3 Docker Stop" "runs Docker stop.sh in /scripts" \
        "P4 Docker Restart" "Restart" \
        "P5 Docker Prune volumes" "prune volumes that are stale unattached([safe])" \
        "P6 Docker Prune images" "prune images that are stale or unattached([safe],saving lots of space!)" \
        3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        return 0
    elif [ $RET -eq 0 ]; then
        case "$FUN" in
            P1\ *) do_bash_aliases ;;
            P2\ *) do_start_stack ;;
            P3\ *) do_stop_stack ;;
            P4\ *) do_restart_stack ;;
            P5\ *) do_prune_volumes_stack ;;
            P6\ *) do_prune_images_stack ;;
            *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
        esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
    fi
}

do_swap() {
    log_message "INFO" "Disabling swap file (requires sudo)"
    if [ ! -n "$SUDO_USER" ]; then
        log_message "WARNING" "Disabling swap requires sudo. Please run with sudo for this operation."
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "Disabling swap requires sudo. Please run 'sudo ./presto_launch.sh' for this option." 20 60 2
        fi
        return 1
    fi
    sudo dphys-swapfile swapoff && \
    sudo dphys-swapfile uninstall && \
    sudo update-rc.d dphys-swapfile remove && \
    sudo systemctl disable dphys-swapfile || { log_message "ERROR" "Failed to disable swap file"; return 1; }
    log_message "INFO" "Swap file has been disabled"
    if [ "$INTERACTIVE" = True ]; then
        whiptail --msgbox "[presto] Swap file removed" 20 60 2
    fi
}

do_swappiness() {
    log_message "INFO" "Setting swappiness to 0 (requires sudo)"
    if [ ! -n "$SUDO_USER" ]; then
        log_message "WARNING" "Setting swappiness requires sudo. Please run with sudo for this operation."
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "Setting swappiness requires sudo. Please run 'sudo ./presto_launch.sh' for this option." 20 60 2
        fi
        return 1
    fi
    if [ $(grep -c swappiness /etc/sysctl.conf) -eq 0 ]; then
        echo "vm.swappiness=0" | sudo tee -a /etc/sysctl.conf || { log_message "ERROR" "Failed to update sysctl.conf"; return 1; }
        log_message "INFO" "Updated /etc/sysctl.conf with vm.swappiness=0"
    else
        sudo sed -i "/vm.swappiness/c\vm.swappiness=0" /etc/sysctl.conf || { log_message "ERROR" "Failed to modify swappiness in sysctl.conf"; return 1; }
        log_message "INFO" "vm.swappiness found in /etc/sysctl.conf updated to 0"
    fi
    sudo sysctl vm.swappiness=0 || { log_message "ERROR" "Failed to set swappiness"; return 1; }
    log_message "INFO" "Set swappiness to 0 for immediate effect"
}

do_log2ram() {
    log_message "INFO" "Installing log2ram (requires sudo)"
    if [ ! -n "$SUDO_USER" ]; then
        log_message "WARNING" "log2ram installation requires sudo. Please run with sudo for this operation."
        if [ "$INTERACTIVE" = True ]; then
            whiptail --msgbox "log2ram installation requires sudo. Please run 'sudo ./presto_launch.sh' for this option." 20 60 2
        fi
        return 1
    fi
    if [ ! -d "$USER_HOME/log2ram-master" ]; then
        log_message "INFO" "Downloading and installing log2ram"
        curl -L https://github.com/azlux/log2ram/archive/master.tar.gz | tar zxf - || { log_message "ERROR" "Failed to download log2ram"; return 1; }
        cd log2ram-master
        chmod +x install.sh && sudo ./install.sh || { log_message "ERROR" "Failed to install log2ram"; cd ..; rm -r log2ram-master; return 1; }
        cd ..
        rm -r log2ram-master
        log_message "INFO" "log2ram installed successfully"
    else
        log_message "INFO" "log2ram already installed"
    fi
}

do_extratools_menu() {
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (presto-config)" --menu "Performance Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
        "P1 swap" "disable your swap file - if u have plenty ram" \
        "P2 swappiness" "set swappiness to 0 - if you have plenty ram" \
        "P3 log2ram" "installs log2ram (to save your ssd/nvme constant writes)" \
        3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        return 0
    elif [ $RET -eq 0 ]; then
        case "$FUN" in
            P1\ *) do_swap ;;
            P2\ *) do_swappiness ;;
            P3\ *) do_log2ram ;;
            *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
        esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
    fi
}

do_backups_menu() {
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (presto-config)" --menu "Performance Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
        "P1 Install rclone for Backups of presto sys " "runs rclone install ready for gdrive setup /scripts" \
        "P2 Backup" "runs Backup/scripts" \
        "P3 Restore" "runs Restore /scripts" \
        3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        return 0
    elif [ $RET -eq 0 ]; then
        case "$FUN" in
            P1\ *) do_rclone_install ;;
            P2\ *) do_backup_gdrive ;;
            P3\ *) do_restore_gdrive ;;
            *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
        esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
    fi
}

do_about() {
    whiptail --msgbox "\
HELLO presto $USER : This tool provides a straightforward way of doing initial
configuration of the Raspberry Pi for MEDIA AWESOMENESS!. Although it can be run
at any time, some of the options may have difficulties if
you have heavily customised your installation.
$(dpkg -s raspi-config 2> /dev/null | grep Version)\
" 20 70 1
    log_message "INFO" "Displayed about information"
    return 0
}

do_install_prestobashwelcome() {
    if grep -Fxq ". $USER_HOME/presto-tools/scripts/presto_bashwelcome.sh" "$USER_HOME/.bashrc"; then
        log_message "INFO" "Found presto Welcome login link in bashrc. No changes needed."
    else
        log_message "INFO" "presto Welcome Bash (in bash.rc) is missing. Adding now..."
        printf "\n#presto-tools Added: presto_bash_welcome scripty\n" >> "$USER_HOME/.bashrc"
        printf ". $USER_HOME/presto-tools/scripts/presto_bashwelcome.sh\n" >> "$USER_HOME/.bashrc"
        log_message "INFO" "presto_bash_welcome script added to ~/.bashrc."
    fi

    if [ ! -d "$USER_HOME/presto-tools" ]; then
        log_message "INFO" "Cloning presto-tools repository"
        git clone https://github.com/piklz/presto-tools "$USER_HOME/presto-tools" || { log_message "ERROR" "Failed to clone presto-tools"; return 1; }
        chmod +x "$USER_HOME/presto-tools/scripts/prestotools_install.sh"
        log_message "INFO" "Running presto-tools install"
        pushd "$USER_HOME/presto-tools/scripts" && sudo ./prestotools_install.sh || { log_message "ERROR" "Failed to run prestotools_install.sh"; popd; return 1; }
        popd
    else
        log_message "INFO" "presto-tools scripts directory already installed"
    fi

    log_message "INFO" "Presto welcome bash setup completed"
    echo -e "${COL_LIGHT_RED}${INFO}${clear}${COL_LIGHT_GREEN}Presto WELCOME BASH created! Logout and re-login to test\n"
    source "$USER_HOME/.bashrc" || log_message "WARNING" "Failed to source .bashrc"
}

# Main menu
if [ "$INTERACTIVE" = True ]; then
    calc_wt_size
    while [ -z "$USER" ]; do
        if ! USER=$(whiptail --inputbox "presto could not determine the default user.\\n\\nWhat user should these settings apply to?" 20 60 pi 3>&1 1>&2 2>&3); then
            log_message "INFO" "User input cancelled, exiting"
            return 0
        fi
        USER_HOME=$(getent passwd "$USER" | cut -d: -f6)
    done
    log_message "INFO" "Starting presto main menu for user $USER"
    while true; do
        if is_pi; then
            FUN=$(whiptail --title "presto SYSTEM Raspberry Pi Software Configuration Tool (presto_launch.sh)" --backtitle "$(tr -d '\0' < /proc/device-tree/model) presto VERSION: ${presto_VERSION}" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
                "1 Install" "Install Docker+Docker-compose" \
                "2 Build Docker Stack" "build compose stack of apps list!" \
                "3 Commands" "useful Docker commands" \
                "4 Extra tools" "useful extras tools settings for pi" \
                "5 Backing up" "Configure Google Drive Backup|Restore of presto!" \
                "6 Update presto" "Update presto tools to the latest version (via github)" \
                "7 Update Docker-Compose" "Update Dockers compose system" \
                "8 About presto" "Information about this configuration tool" \
                3>&1 1>&2 2>&3)
        fi
        RET=$?
        if [ $RET -eq 1 ]; then
            do_finish
        elif [ $RET -eq 0 ]; then
            case "$FUN" in
                1\ *) do_install_docker_menu ;;
                2\ *) do_build_stack_menu ;;
                3\ *) do_dockercommands_menu ;;
                4\ *) do_extratools_menu ;;
                5\ *) do_backups_menu ;;
                6\ *) do_update ;;
                7\ *) do_compose_update ;;
                8\ *) do_about ;;
                *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
            esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
        else
            log_message "ERROR" "Unexpected menu return code: $RET"
            exit 1
        fi
    done
fi