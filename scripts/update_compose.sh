#!/bin/bash
DCV=$(docker compose version)

echo  ""
echo  -e "\e[32;1m Current: $DCV \e[0m"

echo  -e "\e[33;1m    Stopping Docker compose plugin \e[0m"
docker compose down

echo  -e "\e[33;1m    Removing Docker-compose\e[0m"
sudo apt-get remove docker-compose-plugin -y &> /dev/null

#echo  -e "\e[33;1m    Getting Python3\e[0m"
#sudo apt-get install libffi-dev libssl-dev -y &> /dev/null
#sudo apt-get install python3-dev -y &> /dev/null
#sudo apt-get install python3 python3-pip -y &> /dev/null

echo  -e "\e[33;1m    Installing new Docker-compose-plugin v2 \e[0m"
#sudo pip3 install docker-compose  &> /dev/null  #deprecated in future?lets use apt way docker suggests of compose v2 
sudo apt-get install -y docker-compose-plugin &> /dev/null

echo  -e "\e[33;1m    Starting stack up again\e[0m"
docker compose up -d

#DCV=$(docker-compose --version)
DCV=$(docker compose version)
echo  -e "\e[32;1m Updated current plugin version: $DCV\e[0m"
echo  ""
