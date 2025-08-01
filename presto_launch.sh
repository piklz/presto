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
# docker media stack script installer menu , serving up media apps to run plex server  and its 
# supporting apps inc many support apps for remote access media graphing or pi status checking
# anywhere , remix alot of code from various rpi configs docker gits examples 
#--------------------------------------------------------------------------------------------------
#author		: piklz
#github		: https://github.com/piklz/presto.git
#web		  : https://github.com/piklz/presto.git
##################################################################################################

#lets gooooooooo

presto_VERSION='1.1.0' 


INTERACTIVE=True

#usefull for bash updates alias 
# changes docker installs etc in functions...

ASK_TO_REBOOT=0


#USER=${SUDO_USER:-$(who -m | awk '{ print $1 }')} either work the same checks if sudo user is empty and gets a name  for it if not

if [ -z "${USER}" ]; then
    USER="$(id -un)"
fi


INIT="$(ps --no-headers -o comm 1)"


sys_arch=$(uname -m) #eg. returns aarch64 



presto_INSTALL_DIR="/home/$USER/presto"
if [ ! -d "$presto_INSTALL_DIR" ]; then
    mkdir -p "$presto_INSTALL_DIR"
fi
cd "$presto_INSTALL_DIR" || { echo "Could not enter $presto_INSTALL_DIR"; exit 1; }


# todo maybe.. but generally this is to be on raspian/debian  mainly... /home
# eg. should return /home/pi/ or diff users name as needed
# user_home=$(getent passwd "$USER" | cut -d: -f6)


#================================================================================================

# Function to display a spinner animation and handle termination


# Set these values so the installer can still run in color
COL_NC='\e[0m' # No Color
COL_LIGHT_GREEN='\e[1;32m'
COL_GREEN='\e[0;3m'
COL_LIGHT_RED='\e[1;31m'
TICK="[${COL_LIGHT_GREEN}✓${COL_NC}]"
CROSS="[${COL_LIGHT_RED}✗${COL_NC}]"
INFO="[i]"
DONE="${COL_LIGHT_GREEN} done!${COL_NC}"
OVER="\\r\\033[K"

# Color variables
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
# Clear the color after that
clear='\033[0m'




# do a check on docker-compose updates and install via .sh  in scripts dir

do_compose_update() {
   
      echo -e "\e[33;1m${INFO} Docker Compose update running ... .\e[0m"
      
      ${presto_INSTALL_DIR}/scripts/update_compose.sh
 
}

# check git and clone presto if needed usually on first run on clean rasp os

check_git_and_presto() {
  PRESTO_DIR="$HOME/presto"

  echo -e "${INFO} check and presto starting up>"

  # 1. Ensure git is installed
  if ! command -v git >/dev/null 2>&1; then
    whiptail_return=$(whiptail --yesno "Git is not installed. Would you like to install it now?" 20 60 3>&1 1>&2 2>&3; echo $?)
    if [[ $whiptail_return == 0 ]]; then
      echo -e "${INFO} Installing git now via apt"
      sudo apt update && sudo apt install git -y
    else
      echo -e "${CROSS} Git is required. Exiting."
      exit 1
    fi
  fi

  # 2. Ensure $PRESTO_DIR is a valid git repo, otherwise safely re-clone
  if [[ ! -d "$PRESTO_DIR/.git" ]]; then
    if [[ -d "$PRESTO_DIR" ]]; then
      # If the script is currently in (or under) $PRESTO_DIR, cd to $HOME first!
      if [[ "$PWD" == "$PRESTO_DIR"* ]]; then
        cd "$HOME" || exit 1
      fi
      echo "[i] Removing incomplete or non-git $PRESTO_DIR directory."
      rm -rf "$PRESTO_DIR"
    fi
    echo "[i] Cloning presto repository..."
    git clone -b main https://github.com/piklz/presto "$PRESTO_DIR"
  fi

  # 3. Move into the repo and check for updates
  cd "$PRESTO_DIR" || { echo "Failed to cd into $PRESTO_DIR"; exit 1; }
  echo -e "${INFO}${COL_LIGHT_GREEN} Checking PRESTO Git updates\n ${clear}"
  git fetch

  if git status | grep -q "Your branch is up to date"; then
    [ -f .outofdate ] && rm .outofdate
    echo -e "${INFO} ${COL_LIGHT_GREEN} Git local/repo is up-to-date${clear}"
  else
    echo -e "${INFO} ${COL_LIGHT_GREEN} Update is available${TICK}"
    if [ ! -f .outofdate ]; then
      whiptail --title "Project update" --msgbox "PRESTO update is available (select option 6 to grab update)\nYou will not be reminded again until your next update" 8 78
      touch .outofdate
      # If you want to auto-update, call do_update here.
    fi
  fi
}



#RUN
check_git_and_presto


do_update() {
        echo -e "${INFO} ${COL_LIGHT_GREEN} Pulling latest project file from Github"
                
        # lets grab latest MAIN repo
        git pull origin main

        # to be sure lets fix execute bits on the scripts
        find scripts/ -name '*.sh' -type f -exec chmod +x {} +

        #echo "${INFO} ${COL_LIGHT_GREEN} git status ------------------------------------------------------------------------------"
        [ -f .outofdate ] && rm .outofdate       #rm tmp check cos we are uptodate now
        #git status
        return 0
}




#grab timezones if env exists with service
timezones() {

	env_file=$1
	TZ=$(cat /etc/timezone)

	#test TimeZone=
	[ $(grep -c "TZ=" $env_file) -ne 0 ] && sed -i "/TZ=/c\TZ=$TZ" $env_file

}




is_pi () {
  ARCH=$(dpkg --print-architecture)
  if [ "$ARCH" = "armhf" ] || [ "$ARCH" = "arm64" ] ; then
    return 0
  else
    return 1
  fi
}





# terminal size height 

calc_wt_size() {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error 
  # output from tput. However in this case, tput detects neither stdout or 
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=18
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}



do_finish() {
  
  if [ $ASK_TO_REBOOT -eq 1 ]; then
    whiptail --yesno "Would you like to reboot now?" 20 60 2
    if [ $? -eq 0 ]; then # yes
      sync
      sudo reboot now
    fi
  fi
  exit 0
}




#START NEW ITEMS HERE ---------------------------------------------------------------------
#Menu Display Name DOCKER SERVICES SELECTION LISTS HERE add and change as you wish to add more services (and also make a .template file too to match to docker image specs)
#[CONTAINER NAME]="MENU Text"



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
	[pihole]="pi-hole >  adblocker!"
	[wgui]="Wireguard-UI > web portal for for wireguard vpn config"
  [uptimekuma]="uptime-kuma all your base system health monitor"
  [syncthing]="Syncthing > the sync tools you always wanted webui easy to use "	
  [photoprism]="Photoprism > your own google photos ! with ai-tensor for tagging "	
  [glances]="Glances  > An eye on your system"	
  [prowlarr]="Prowlarr > Prowlarr supports both Torrent Trackers and Usenet Indexers."
  [homepage]="Homepage > customizable application dashboard"
  [ittools]="it-tools > nice IT. tools in one place "
)

declare -a aarch64_keys=(
  "portainer"
  "sonarr"
  "radarr"
  "lidarr"
  "jackett"
  "qbittorrent"
  "jellyfin"
  "plex"
  "tautulli"
  "overseerr"
  "heimdall"
  "homeassistant"
  "motioneye"
  "homarr"
  "wireguard"
  "pihole"
  "wgui"  
  "uptimekuma"
  "syncthing"
  "photoprism"
  "glances"
  "prowlarr"
  "homepage"
  "ittools"
)

#--FINISH add your two item entries per new services added in templates etc----------




#function copies the template yml file to the local service folder and appends to the docker-compose.yml file
function yml_builder() {

	service="services/$1/service.yml"
 

	[ -d ./services/ ] || mkdir ./services/
 

		if [ -d ./services/$1 ]; then
			#directory already exists prompt user to overwrite
			service_overwrite=$(whiptail --radiolist --title "Deployment Option" --notags \
				"$1 was already created before, use [SPACEBAR] to select redeployment configuation" 20 78 12 \
				"none" "Use recent config" "ON" \
				"env" "Preserve Environment and Config files" "OFF" \
				"full" "Pull config from template" "OFF" \
				3>&1 1>&2 2>&3)

			case $service_overwrite in

			"full")
        echo "...pulled full $1 from template"
            #rm -rf ./services/$1/*  # Remove existing files before copying (full overwrite)
        rsync -a -q .templates/$1/ services/$1/ --exclude 'build.sh'
        ;;
			"env")
        echo "...pulled $1 from github local excluding env/conf files"
        rsync -a -q .templates/$1/ services/$1/ --exclude 'build.sh' --exclude '$1.env' --exclude '*.conf'
        ;;
			"none")
        echo "...$1 service files not overwritten"
        ;;

			esac

		else
			mkdir ./services/$1
			echo "...pulled full $1 from template Dir"
			rsync -a -q .templates/$1/ services/$1/ --exclude 'build.sh'
		fi


	#if an env file exists check for timezone
	[ -f "./services/$1/$1.env" ] && timezones ./services/$1/$1.env
 
 	echo "" >> docker-compose.yml
  
        # Append the service only if it's not already in the docker-compose.yml file
	# AND if it's currently selected
	if ! grep -q "services:$1:" docker-compose.yml && [[ "${containers[@]}" =~ "$1" ]]; then
	  cat $service >> docker-compose.yml
	fi
 
 	
}




do_bash_aliases() {
	touch ~/.bash_aliases
	mkdir -p $HOME/presto
	touch $HOME/presto/.presto_bash_aliases
	if ! grep -q 'presto/.presto_bash_aliases' ~/.bash_aliases; then
    	echo ". $HOME/presto/.presto_bash_aliases" >>~/.bash_aliases
    	echo -e "${INFO} Created presto aliases(presto/.presto_bash_aliases)!"
	#echo -e "${INFO} Created presto aliases \(presto/.presto_bash_aliases\)!"
			if [ "$INTERACTIVE" = True ]; then
				whiptail --msgbox "CREATED presto bash_aliases. presto_up,presto_down,\
        presto_start,presto_stop,presto_update,presto_build,presto_status,cpv,\
        presto_upgrade-pi-sys,presto_dusummary,presto_status_usage,presto_status_usage2 & more!" 20 80 2
      fi
		else
			echo "presto' bash aliases already added!"
				if [ "$INTERACTIVE" = True ]; then
                                whiptail --msgbox "presto bash aliases already created." 20 60 2
                                fi
		fi
		source ~/.bashrc
		
		ASK_TO_REBOOT=1

		if [ "$INTERACTIVE" = True ]; then
                                whiptail --msgbox "presto aliases will be ready after a reboot" 20 60 2
                                fi
		echo -e "${INFO} PRESTO aliases will be ready after a reboot/logout"

}




#------ docker do_start* scripts launchers


# "start" ./scripts/start.sh ;;
# "stop" ./scripts/stop.sh ;;
#	"stop_all" ./scripts/stop-all.sh ;;
#	"restart" ./scripts/restart.sh ;; 
#	"pull" ./scripts/update.sh ;; pull images
#	"prune_volumes" ./scripts/prune-volumes.sh ;; deletes unused tagless unattached to process volumes
#	"prune_images" ./scripts/prune-images.sh ;;   deleets unses and attached images 



do_start_stack() {

if [ -e ${presto_INSTALL_DIR}/scripts/start.sh ]; then
	# shellcheck disable=SC1091
 	source "${presto_INSTALL_DIR}/scripts/start.sh"

	local str="running docker start script"
        printf "\\n  %b %s..." "${INFO}" "${str}"
	wait
        sleep 3
fi
#: <<'END_COMMENT'
if [ "$INTERACTIVE" = True ]; then
         whiptail --msgbox "presto docker stack started" 20 60 2
         fi
       #echo "presto docker start"
#END_COMMENT
#exit 0
}


do_stop_stack(){
if [ -e ${presto_INSTALL_DIR}/scripts/stop.sh ]; then
        # shellcheck disable=SC1091
        source "${presto_INSTALL_DIR}/scripts/stop.sh"

        local str="running Docker Stop script"
        printf "\\n  %b %s..." "${INFO}" "${str}"
	wait
        sleep 3
fi
#: <<'END_COMMENT'
if [ "$INTERACTIVE" = True ]; then
         whiptail --msgbox "presto Docker stacks stopped" 20 60 2
         fi
       #echo "presto docker Stop"
#END_COMMENT
#exit 0
}


do_update_stack(){ 
if [ -e ${presto_INSTALL_DIR}/presto/scripts/update.sh ]; then
        # shellcheck disable=SC1091
        source "${presto_INSTALL_DIR}/scripts/update.sh"
        local str="running Docker update stack script"
        printf "\\n  %b %s..." "${INFO}" "${str}"
	wait
        sleep 3
fi
#: <<'END_COMMENT'
if [ "$INTERACTIVE" = True ]; then
         whiptail --msgbox "presto Docker update stacks started" 20 60 2
         fi
       #echo "presto docker updating stack pulling images if newer/needed"
#END_COMMENT
#exit 0
}




do_restart_stack(){
if [ -e ${presto_INSTALL_DIR}/scripts/restart.sh ]; then
        # shellcheck disable=SC1091
        
	source "${presto_INSTALL_DIR}/scripts/restart.sh"
        local str="Docker restart script Finished. Returning you back to Menu"
        printf "\\n  %b %s..." "${INFO}" "${str}"
	wait
	sleep 3
fi
#: <<'END_COMMENT'
if [ "$INTERACTIVE" = True ]; then
         whiptail --msgbox "presto Docker stacks restart" 20 60 2
         fi
       #echo "presto docker stack restart"
#END_COMMENT
#exit 0
}


do_prune_volumes_stack(){
if [ -e ${presto_INSTALL_DIR}/scripts/prune-volumes.sh ]; then
        # shellcheck disable=SC1091
        source "${presto_INSTALL_DIR}/scripts/prune-volumes.sh"
        local str="running Docker prune-volumes script"
        printf "\\n  %b %s..." "${INFO}" "${str}"
	wait
        sleep 3
fi
#: <<'END_COMMENT'
if [ "$INTERACTIVE" = True ]; then
         whiptail --msgbox "presto Docker Prune volume stacks " 20 60 2
         fi
       #echo "presto docker prune volumes started-stale vlumes deleted(generally saf+e to run)"
#END_COMMENT
#exit 0
}


do_prune_images_stack(){
if [ -e ${presto_INSTALL_DIR}/scripts/prune-images.sh ]; then
        # shellcheck disable=SC1091
        source "${presto_INSTALL_DIR}/scripts/prune-images.sh"
	
        local str="running Docker prune-images script"
        printf "\\n  %b %s..." "${INFO}" "${str}"
	wait
        sleep 3
fi
#: <<'END_COMMENT'
if [ "$INTERACTIVE" = True ]; then
         whiptail --msgbox "presto Docker prune images stacks started" 20 60 2
         fi
       #echo "presto docker Stop"
#END_COMMENT
#exit 0
}




# DOCKER build install MAIN-MENU -----------------------------------

do_install_docker_menu() {
if is_pi ; then
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "System Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
      "S1 Install DOCKER|COMPOSE(REQUIRED)" "Installs main base system:  Docker + Docker Compose" \
      "S2 Build Stack" "Use the [SPACEBAR] to select which containers you would like to use" \
      "S3 Install presto Bash Welcome" "creates link to  bash script added info for  '$USER' user" \
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

do_dockersystem_install(){
  # Add Docker's official GPG key:
  sudo apt-get update -y
  sudo apt-get install ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg -y

  # Add the repository to Apt sources:
  echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update

  #install part
  sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
  
  #Create the docker group.
  echo -e "${INFO} Adding group user docker now }"
  sudo groupadd docker

  #Add your user to the docker group.
  echo -e "${INFO} Adding ${USER} to docker grp now }"
  sudo usermod -aG docker $USER &> /dev/null
  echo -e "${INFO}    Docker is Installed! for $USER${TICK}"


  ASK_TO_REBOOT=1

        if [ "$INTERACTIVE" = True ]; then
             whiptail --msgbox "PRESTO recommends a reboot now\n" 20 60 2
        fi
        

  #echo "presto needs a reboot now "
  local str="PRESTO recommends a restart now"
  printf "\\n  %b %s..." "${INFO}" "${str}"

  do_finish
}




do_build_stack_menu() {

	title=$'Container Selection'
	message=$'Use the [SPACEBAR] to select which containers you would like to use then tab for OK|skip'
	entry_options=()

	#check architecture and display appropriate menu
	if [ $(echo "$sys_arch" | grep -c "arm") ]; then
		keylist=("${aarch64_keys[@]}")
	else
		echo "your architecture is not supported yet"
		exit
	fi

	#loop through the array of descriptions
	for index in "${keylist[@]}"; do
		entry_options+=("$index")
		entry_options+=("${cont_array[$index]}")

		#check selection
		if [ -f ./services/selection.txt ]; then
			[ $(grep "$index" ./services/selection.txt) ] && entry_options+=("ON") || entry_options+=("OFF")
		else
			entry_options+=("OFF")
		fi
	done

	container_selection=$(whiptail --title "$title" --notags --separate-output --checklist \
		"$message" 20 78 12 -- "${entry_options[@]}" 3>&1 1>&2 2>&3)

	mapfile -t containers <<<"$container_selection"

	#if no container is selected then dont overwrite the docker-compose.yml file
	if [ -n "$container_selection" ]; then
		touch docker-compose.yml
		#echo "version: '3'" >docker-compose.yml #newer docker commpose does not care for this 
	
	echo "networks:" > docker-compose.yml
	echo "  private_network:" >> docker-compose.yml
	echo "    name: \"pihole-dns\"" >> docker-compose.yml
	echo "    driver: bridge" >> docker-compose.yml
	echo "    ipam:" >> docker-compose.yml
	echo "      config:" >> docker-compose.yml
	echo "        - subnet: 172.19.0.0/24 #prestos internal docker network pihole to wireguard etc" >> docker-compose.yml
	echo "          #gateway: 172.19.0.1" >> docker-compose.yml
	
	echo "services:" >>docker-compose.yml
       

		#set the ACL for the stack
		#docker_setfacl

		# store last selection
		[ -f ./services/selection.txt ] && rm ./services/selection.txt
		#first run service directory wont exist
		[ -d ./services ] || mkdir services
		touch ./services/selection.txt

		#Run yml_builder of all selected containers
		for container in "${containers[@]}"; do
			echo "Adding $container container"
			yml_builder "$container"
			echo "$container" >>./services/selection.txt
   			#echo "$container" > ./services/selection.txt  # Overwrite selection file with current container
		done

		# add custom containers
		if [ -f ./services/custom.txt ]; then
			if (whiptail --title "Custom Container detected" --yesno "custom.txt has been detected do you want to add these containers to the stack?" 20 78); then
				mapfile -t containers <<<$(cat ./services/custom.txt)
				for container in "${containers[@]}"; do
					echo "Adding $container container"
					yml_builder "$container"
				done
			fi
		fi

    
		echo "docker-compose.yml successfully created"
		echo -e "run \e[104;1mdocker-compose up -d or 'presto_up'\e[0m to start the stack"
		
		if [ "$INTERACTIVE" = True ]; then
                        whiptail --msgbox "[presto] Build Stack FINISHED !RUN 'docker-compose up -d' or 'presto_upto' start the stack in terminal" 20 60 2

                fi

	else

		echo "Build cancelled"
		
		
		if [ "$INTERACTIVE" = True ]; then
            		whiptail --msgbox "presto Build stack cancelled" 20 60 2
			
 	 	fi
		
		
	fi

}



do_rclone_install() {

	  if [[  -f  /usr/bin/rclone ]]  &&   rclone listremotes | grep -w 'gdrive:'  >> /dev/null ; then

        #rclone installed and gdrive exist
			echo -e "\e[32m=====================================================================================\e[0m"
			echo -e "\e[36;1m    rclone installed and gdrive configured, go to Backup or Restore \e[0m" 
   		    echo -e "\e[32m=====================================================================================\e[0m"
	else

		  #I'm using rclones web downloads script for more recent updated versions of rclone  than apt or snap provides

		  #To install rclone on Linux/macOS/BSD systems, run:

      sudo -v ; curl https://rclone.org/install.sh | sudo bash

      #comment above version & UNCOMMENT BELOW For beta installation, run:

      #sudo -v ; curl https://rclone.org/install.sh | sudo bash -s beta
      

			echo -e "\e[32m=====================================================================================\e[0m"
			echo -e "     Please run \e[32;1mrclone config\e[0m and create remote \e[34;1m(gdrive)\e[0m for backup   "
			echo -e "     "
			echo -e "     Do as folows:"
			echo -e "      [n] ['gdrive'] [12 or 23 or more recent versions are 18) make sure its 'drive'] [Enter] [Enter] [1] [Enter] [Enter] [n] [n]"
			echo -e "      [Copy link from SSH console and paste it into the browser]"
			echo -e "      [Login to your google account]"
			echo -e "      [Copy token from Google and paste it into the SSH console]"
			echo -e "      [n] [y] [q]"
			echo -e "\e[32m=====================================================================================\e[0m"
			


			#pop up interactive info too 
	whiptail --msgbox "\

     Please run rclone config and create remote (gdrive) for backup

 Do steps in terminal follows:
 [n] [gdrive] [12 or 13 or 18 make sure its 'drive'] [Enter] [Enter] [1] [Enter] [Enter] [n] [n]
 [Copy link from SSH console and paste it into the browser]
 [Login to your google account]
 [Copy token from Google and paste it into the SSH console]
 [n] [y] [q]
    " 20 100 1
  return 0

  fi
}



do_backup_gdrive() {
	
	source "${presto_INSTALL_DIR}/scripts/rclone_backup.sh"


}

do_restore_gdrive() {

	source "${presto_INSTALL_DIR}/scripts/rclone_restore.sh"


}


#------------------------------------------
#docker command scripts MENU

do_dockercommands_menu() {
  FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (presto-config)" --menu "Performance Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "P1 Add presto_up and presto_down aliases" "set useful bash cmd aliases" \
    "P2 Docker Start" "runs Docker start.sh in /scripts" \
    "P3 Docker Stop" "runs Docker stop.sh in /scripts" \
    "P4 Docker Restart" "Restart" \
    "P5 Docker Prune volumes" "prune volumes that are stale unattached([safe])" \
    "P6 Docker Prune images" "prune imagess that are stale or unattached([safe],saving lots of space!)" \
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

#-----------------------------------------------------------------------
#  from extratoolsmenu() -- 3 helpers

do_swap(){
    sudo dphys-swapfile swapoff
		sudo dphys-swapfile uninstall
		sudo update-rc.d dphys-swapfile remove
		sudo systemctl disable dphys-swapfile
		#sudo apt-get remove dphys-swapfile

		echo -e "$INFO${green}Swap file has been disabled${clear}"

    if [ "$INTERACTIVE" = True ]; then
         whiptail --msgbox "[presto] Swap file removed" 20 60 2
         fi



}

do_swappiness(){

if [ $(grep -c swappiness /etc/sysctl.conf) -eq 0 ]; then
			echo "vm.swappiness=0" | sudo tee -a /etc/sysctl.conf
			echo "updated /etc/sysctl.conf with vm.swappiness=0"
		else
			sudo sed -i "/vm.swappiness/c\vm.swappiness=0" /etc/sysctl.conf
			echo "vm.swappiness found in /etc/sysctl.conf update to 0"
		fi

		sudo sysctl vm.swappiness=0
		echo "set swappiness to 0 for immediate effect"

}

do_log2ram(){

if [ ! -d ~/log2ram-master ]; then
			curl -L https://github.com/azlux/log2ram/archive/master.tar.gz | tar zxf -
      cd log2ram-master
      chmod +x install.sh && sudo ./install.sh
      cd ..
      rm -r log2ram-master
		else
			echo "log2ram already installed"
		fi

}




do_extratools_menu() {

#echo -e "${red} extra scripts  here "

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
  return 0
}




do_install_prestobashwelcome() {
if grep -Fxq ". /home/$USER/presto-tools/scripts/presto_bashwelcome.sh" /home/$USER/.bashrc ; then
    # code if found
	echo "Found presto Welcome login link in bashrc no changes needed -continue check if prestotools git installed.."

else
    # add code if not found
  echo -e "${COL_LIGHT_RED}${INFO}${clear} ${COL_LIGHT_RED}presto Welcome Bash  (in bash.rc ) is missing ${clear}"
	echo -e "${COL_LIGHT_RED}${INFO}${clear} ${COL_LIGHT_RED}lets add presto_bashwelcome  mod to .bashrc now >${clear}"


	#bashwelcome add to bash.rc here
	echo  "#presto-tools Added: presto_bash_welcome scripty" >> /home/$USER/.bashrc
	echo ". /home/$USER/presto-tools/scripts/presto_bashwelcome.sh" >> /home/$USER/.bashrc
fi 

#lets check if there already / git clone it and run it
if [ ! -d $HOME/presto-tools ]; then
  echo "GIT cloning the presto-tools now:\n"
	git clone https://github.com/piklz/presto-tools $HOME/presto-tools
	chmod +x $HOME/presto-tools/scripts/prestotools_install.sh
  echo "running presto-tools install..>:\n"
	pushd $HOME/presto-tools/scripts && sudo ./prestotools_install.sh
	popd
else
	echo "presto-tools scripts dir already installed - continue"
fi
  
  #all done done 
  echo -e "${COL_LIGHT_RED}${INFO}${clear}files added from git or bash links modded.(bash.rc)\n "
	echo -e "${COL_LIGHT_RED}${INFO}${clear}${COL_LIGHT_GREEN}prestos WELCOME BASH created! Logout and re-login to test  \n"

  source ~/.bashrc
  
}





# MAIN MENU presto First Dialog Starts Here
# Interactive use loop



if [ "$INTERACTIVE" = True ]; then
  [ -e $CONFIG ] || touch $CONFIG
  calc_wt_size
  while [ "$USER" = "root" ] || [ -z "$USER" ]; do
    if ! USER=$(whiptail --inputbox "presto could not determine the default user.\\n\\nWhat user should these settings apply to?" 20 60 pi 3>&1 1>&2 2>&3); then
      return 0
    fi
  done
  while true; do
    if is_pi ; then
      FUN=$(whiptail --title "presto SYSTEM Raspberry Pi Software Configuration Tool (presto_launch.sh)" --backtitle "$(tr -d '\0' <  /proc/device-tree/model) presto VERSION: ${presto_VERSION}" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
        "1 Install" "Install Docker+Docker-compose" \
        "2 Build Docker Stack  " "build compose stack of apps list! " \
        "3 Commands" "useful Docker commands" \
        "4 Extra tools" "useful extras tools settings for pi" \
        "5 Backing up" "Configure Google Drive Backup|Restore of presto!" \
        "6 Update presto" "Update presto tools to the latest version (via github)" \
	      "7 Update Docker-Compose " "Update Dockers compose system" \
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
      exit 1
    fi
  done
fi
