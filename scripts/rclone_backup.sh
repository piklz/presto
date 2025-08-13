 #BACKUP [presto docker files]to  Google drive  script 




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



#add enable file for rclone
        [ -d ~/presto/prestoBackups ] || sudo mkdir -p ~/presto/prestoBackups/
        sudo chown pi:pi -R ~/presto/prestoBackups

    if ls ~/presto/ | grep -w 'docker-compose.yml' >> /dev/null ; then

                #create the list of files to backup
        echo "./docker-compose.yml" >list.txt
        echo "./services/" >>list.txt
        echo "./volumes/" >>list.txt

        #setup variables
        logfile=./prestoBackups/log_local.txt
        backupfile="prestobackup-$(date +"%Y-%m-%d_%H-%M").tar.gz"

        #compress the backups folders to archive
        echo -e "\e[32m=====================================================================================\e[0m"
        echo -e "\e[36;1m    Creating backup file ... \e[0m"
                        sudo tar -czf \
                        ./prestoBackups/$backupfile \
                        -T list.txt
                        rm list.txt

        #set permission for backup files
        sudo chown pi:pi ./prestoBackups/presto*

        #create local logfile and append the latest backup file to it
        echo -e "\e[36;1m    Backup file created \e[32;1m $(ls -t1 ~/presto/prestoBackups/presto* | head -1 | grep -o 'prestobackup.*')\e[0m"
        sudo touch $logfile
        sudo chown pi:pi $logfile
        echo $backupfile >>$logfile

        #remove older local backup files
        #to change backups retained,  change below +5 to whatever you want (days retained +1)
        ls -t1 ./prestoBackups/presto* | tail -n +5 | sudo xargs rm -f
        echo -e "\e[36;1m    Backup files are saved in \e[34;1m~/presto/prestoBackups/\e[0m"
        echo -e "\e[36;1m    Only recent 4 backup files are kept\e[0m"

        # check if rclone is installed and gdrive: configured 
        
        #if dpkg-query -W rclone 2>/dev/null | grep -w 'rclone' > /dev/null &&
        #Check if downloaded  rclone exists  (not using dpkg or apt version)
        if [[  -f  /usr/bin/rclone ]]  &&   rclone listremotes | grep -w 'gdrive:' &> /dev/null ; then

        #sync local backups to gdrive (older gdrive copies will be deleted)
                echo -e "\e[36;1m    Syncing to Google Drive ... \e[0m"
        rclone sync -P ./prestoBackups --include "/prestobackup*"  gdrive:/prestoBackups/ > ./prestoBackups/rclone_sync_log
        echo -e "\e[36;1m    Sync with Google Drive \e[32;1mdone\e[0m"
        echo -e "\e[32m=====================================================================================\e[0m"
        else

        echo -e "\e[36;1m    \e[34;1mrclone\e[0m\e[36;1m not installed or \e[34;1m(gdrive)\e[0m\e[36;1m not configured \e[32;1monly local backup created\e[0m"
        echo -e "\e[32m=====================================================================================\e[0m"
        fi

else
                echo -e "${COL_LIGHT_GREEN}=====================================================================================${COL_NC}"
                echo -e "                                                             "
                echo -e "            ${COL_BG_STRAWBERRY}${COL_LIGHT_YELLOW}=============================${COL_NC}"
                echo -e "            ${COL_BG_STRAWBERRY}${COL_WHITE}Containers not deployed yet? ${COL_NC}"
                echo -e "            ${COL_BG_STRAWBERRY}${COL_WHITE}no backup made ✗             ${COL_NC}"
                echo -e "            ${COL_BG_STRAWBERRY}${COL_LIGHT_YELLOW}=============================${COL_NC}"
                echo -e "                                                             "
                echo -e "${COL_LIGHT_GREY}=====================================================================================${COL_NC}"
                fi