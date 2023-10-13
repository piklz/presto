## Perfectly Rationalized  Engine for Superior Tidiness and Organization 
<p><a><img title="presto" src="https://github.com/piklz/presto/assets/2213075/bb569470-1db2-4243-82d1-9ce4c3e420c3" alt="presto logo" height="260" align="left" /> </a></p>
<p><img title="presto" src="https://media.tenor.com/bCAFrsFLh1sAAAAC/dnd-dnd-cartoon.gif" alt="presto" height="250" align="right"/></p>
<table style="border-collapse: collapse; width: 100%;" border="0">
<tbody>
<tr>
<td style="width: 50%;"><strong>The best Usenet/Torrent manager on Android SABnzb, NZBget, Torrents, Sonarr, Radarr, and more. Manage all from one app that focuses on amazing UI/UX. That's nzb360.</strong></td>
<td style="width: 50%;"><img style="display: block; margin-left: auto; margin-right: auto;" src="https://nzb360.com/assets/img/en_badge_web_generic.svg" alt="nzb360 google play image" width="150" height="78" /></td>
</tr>
<tr>
<td style="width: 50%;">&nbsp;</td>
<td style="width: 50%;"><img style="display: block; margin-left: auto; margin-right: auto;" src="https://img.shields.io/github/followers/piklz?style=social" /></td>
</tr>
</tbody>
</table>
# !! CURRENTLY TESTING am adding code for pi5 tests in future and you have to tweak your mount paths in your pi ill have some details tuts o nthis too in this readme soon        
## Requirements

We want that 64bit armv8/AArch64 architecture goodness ]
- All the rpi4's will do (even works on pi3 kinda just depends on how many apps you run at once ) 

| Software | ports |
| --- | --- |
|portainer   | 9000 |
|Sonarr      | 8989 |
|Radarr      | 7878 |
|Lidarr      | 8686 |
|Jackett     | 9117 |
|qBittorrent | 15080|
|Overseerr   | 5055 |
|Tautulli    | 8181 |
|Plex        | 32400|
|rpi-monitor | 8888 |
|homarr      | 7575 |



## Features
- __minimal easeofuse:__ small footprint only use the apps you want and make a stack to launch them easily
- __event backend:__ runs very well and fast on a rpi4 and has alias cmds to do what portainer ui does so great for ssh headless-pi users!
- __small frontend:__ docker runs all the complex stuff and portainer lets you manage it easily and beautifully (but you can also run simple nongui  terminal commands to run preset actions to manage your install and running of presto docker system)


## Table of Contents
- [Features](#features)
- [Requirements](#requirements)
- [Instructions](#instructions)
- [Help](#help)
- [FAQ](#faq)
- [Backing up with google](#routing)


## Installation

This document is for the latest presto release and later**.

- presto release:2023


## How to Use it?
<b>Before you start using <h3 class="font-bold md:text-5xl">presto</h3>, set your Raspberry Pi IP address to be static, it will make some things easier later on.
Static IP address is not absolutely necessary just to try the project and find out if you like it, but i.e. if you would like to properly utilize pihole in your network - you will have to point your router to your RPi IP for DNS resolution.</b>

- install git using a command:
<pre><code>sudo apt-get install git</code></pre>

- Clone the repository with:
<pre><code>git clone https://github.com/piklz/presto.git ~/presto</code></pre>

<i>Do not change name of the folder on your local system it should stay as is for the scripts to work properly</i>

- Enter the directory and run:

<pre><code>cd ~/presto</code></pre>
<pre><code>./presto_launch.sh</code></pre>


## Summary 
- Install Docker and Docker-compose for ARM.
- Choose the Docker containers that you want to install.
- Optionally, install Portainer.
- Run the <code>./presto_launch</code> script to install the presto stack.
- Use the Docker commands to manage the presto stack.
- Disable swapping to the SD card if desired.
- Run the <code>./presto_launch</code> script to check for updates and install them if available.


Here are some additional details about each step:

- Installing Docker and Docker-compose for ARM can take a few minutes. Once they are installed, you will be prompted to reboot your Raspberry Pi.
- When choosing the Docker containers to install, you should consider the RAM requirements of each container. If you are running a Raspberry Pi 3, you may want to avoid installing containers that require a lot of RAM.
- Portainer is a useful tool for managing Docker, but it is not essential. If you do not want to use Portainer, you can manage the Docker containers using the Docker commands.
- The <code>./presto_launch</code> script is a bash script that automates the installation of the presto stack. It is a good idea to run this script once to install the presto stack, and then you can use the Docker commands to manage the stack going forward.
- The Docker commands are a powerful way to manage Docker containers. You can use them to start, stop, and remove containers, as well as to manage their configuration.
- Disabling swapping to the SD card can help to extend the life of your SD card. However, this is not essential, and you may not need to do this if your Raspberry Pi has enough RAM.
- Running the <code>./presto_launch</code> script to check for updates is a good way to make sure that you are always running the latest version of the presto stack. This can be helpful if there are any bug fixes or security updates available.


## presto System :
presto has helper scripts to help non tech folk to clean and maintain their docker container stacks with simple bash aliases 

`subprocess` `printout`

```js
import os,sys,subprocess
os.chdir("/home/pi/presto/scripts/")
##ping = subprocess.Popen("./update.sh",stdout = subprocess.PIPE,stderr = subprocess.PIPE,shell=True) #quietver
update_ping = subprocess.Popen("./update.sh",shell=True) #verbosever
update_out = update_ping.communicate()[0]
output = str(update_out)
##print output
```

### `presto updates and cleans leftover docker volumes/images`


## FAQ







## GOOGLE DRIVE BACKUP FROM HEADLESS PI ! instructions
To use the google drive part of [presto] instructions (to backup your docker containers to the cloud) we have to setup credentials the new google/cloud oauth way (although its not a cloud drive storage we are using..ok! lets go...)


[ OAuth out-of-band (OOB)] is a legacy flow developed to support native clients which do not have a redirect URI like web apps to accept the credentials after a user approves an OAuth consent request. The OOB flow poses a remote phishing risk and clients must migrate to an alternative method to protect against this vulnerability. New clients will be unable to use this flow starting on Feb 28, 2022]

- Feb 28, 2022 - new OAuth usage will be blocked for the OOB flow
- Sep 5, 2022 - a user-facing warning message may be displayed to non-compliant OAuth requests
- Oct 3, 2022 - the OOB flow is deprecated for existing clients

Generally works same way but we have to setup a developer style auth token based credentials relationship ( you probably seen this before with twitter api ,instagram ,github etc as a secure way to access full capabilities of acc via its api..

First we need to create google drive api access credentials!

start by going to this link and start your google cloud acc :

https://console.cloud.google.com/

then follow these instrucitons to make a proper user based of your email acc you have with google and then we use these credentials client id and cliet secret to ask google for auth to get the auth secret < this is what we give to rclone at the end of rclones config setup to enable the gdrive backup acc on your google drive

FAQ: I get quota out of storage type errors 
 -( you have no space on your free 15gb drive(which comes with your google mail acc ) one easy fix is to get a family memeber to invite you to thier (hopefully bigger)google one acc and share their drive storage wiht you !!)
 
