 #RESTORE FROM [presto docker files] Google drive  script 




# colours for script helper
        COL_NC='\e[0m' # No Color
        COL_LIGHT_GREEN='\e[1;32m'
        COL_LIGHT_RED='\e[1;31m'
        TICK="[${COL_LIGHT_GREEN}✓${COL_NC}]"
        CROSS="[${COL_LIGHT_RED}✗${COL_NC}]"
        INFO="[i]"
        # shellcheck disable=SC2034
        DONE="${COL_LIGHT_GREEN} done!${COL_NC}"
        OVER="\\r\\033[K"
        COL_PINK="\e[1;35m"
        COL_LIGHT_CYAN="\e[1;36m"
        COL_LIGHT_PURPLE="\e[1;34m"
        COL_LIGHT_YELLOW="\e[1;33m"
        COL_LIGHT_GREY="\e[1;2m"
        COL_ITALIC="\e[1;3m"
        COL_BG_STRAWBERRY="\e[41m"
        COL_WHITE="\e[1;37m"



# check if rclone is installed and gdrive: configured 
	
	if [[ -f /usr/bin/rclone ]] && rclone listremotes | grep -w 'gdrive:' >> /dev/null ; then	
    	#create backup folder
		[ -d ~/presto/prestoBackups ] || sudo mkdir -p ~/presto/prestoBackups/

		#change permissions to pi
		sudo chown pi:pi ~/presto/prestoBackups
		
		# resync from gdrive to ~/presto/prestoBackups
		rclone sync -P gdrive:/prestoBackups/ --include "/prestobackup*" ./prestoBackups > ./prestoBackups/rclone_sync_log
	    
		# no check if online assume it is online to do 
		echo -e "\e[32m=====================================================================================\e[0m"
		echo -e "${COL_LIGHT_CYAN}   Sync with Google Drive \e[32;1msuccessful${COL_NC}${TICK}"

		# check for recent backup file 
	 	restorefile="$(ls -t1 ~/presto/prestoBackups/presto* | head -1 | grep -o 'prestobackup.*')"
		echo -e "${COL_ITALIC}${COL_LIGHT_GREEN}   Restoring ${COL_LIGHT_RED} $restorefile${COL_NC}"
 
		# stop all container
		echo -e "   ${COL_BG_STRAWBERRY}${COL_LIGHT_YELLOW}Stopping all containers${COL_NC}"
		#show id number and image name 
		sudo docker stop $(docker ps --format "table {{.ID}}\t{{.Image}}") 

		# overwrite all containers
		echo -e "${COL_LIGHT_CYAN}   Restoring all containers from backup${COL_NC}"
		sudo tar -xzf "$(ls -t1 ~/presto/prestoBackups/presto* | head -1)" -C ~/presto/

		# start all containers from docker-comose/yml
		echo -e "${COL_LIGHT_CYAN}   Starting all containers${COL_NC}"
		docker-compose up -d

		sleep 7
		echo -e "${COL_LIGHT_CYAN}   Restore completed\e[0m"
        echo -e "\e[32m=====================================================================================\e[0m"

	else
		echo -e "\e[32m=====================================================================================\e[0m"
		echo -e "\e[36;1m    \e[34;1mrclone\e[0m\e[36;1m not installed or \e[34;1m(gdrive)\e[0m\e[36;1m not configured \e[32;1mchecking local backup\e[0m"

		if ls ~/presto/prestoBackups/ | grep -w 'prestobackup' >> /dev/null ; then

			# local files restore
			echo -e "${COL_LIGHT_GREEN}    Local backup found \e[32;1m"$(ls -t1 ~/presto/prestoBackups/presto* | head -1)"${COL_NC}"

			# stop all container
			echo -e "{COL_BG_STRAWBERRY}${COL_LIGHT_YELLOW}    Stopping all containers${COL_NC}"
			sudo docker stop $(docker ps -a -q) 

			# owerwrite all container
			echo -e "${COL_LIGHT_CYAN}   Restoring all containers from local-backup${COL_NC}"
			sudo tar -xzf "$(ls -t1 ~/presto/prestoBackups/presto* | head -1)" -C ~/presto/

			# start all containers from docker-comose/yml
			echo -e "${COL_LIGHT_CYAN}    Starting all containers${COL_NC}"
			docker-compose up -d

			sleep 7
			echo -e "${COL_LIGHT_CYAN}   Restore completed \e[0m"
     		echo -e "\e[32m=====================================================================================\e[0m"
		else
		        echo -e "${COL_LIGHT_GREEN}=====================================================================================${COL_NC}"
                echo -e "                                                             "
                echo -e "            ${COL_BG_STRAWBERRY}${COL_LIGHT_YELLOW}=============================${COL_NC}"
                echo -e "            ${COL_BG_STRAWBERRY}${COL_WHITE}NO BACKUP FILES FOUND?        ${COL_NC}"
                echo -e "            ${COL_BG_STRAWBERRY}${COL_WHITE}not restoring ✗              ${COL_NC}"
                echo -e "            ${COL_BG_STRAWBERRY}${COL_LIGHT_YELLOW}=============================${COL_NC}"
                echo -e "                                                             "
                echo -e "${COL_LIGHT_GREY}=====================================================================================${COL_NC}"
		fi

	fi
