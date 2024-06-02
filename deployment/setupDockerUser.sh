#!/bin/bash

#exit if not root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

useradd -r -U -M dockeruser
useradd -r -U -M -G docker dockerrunner

groupadd -r dockerfiles
usermod -aG dockerfiles dockerrunner

DOCKERUSER=$(id -u dockeruser)
DOCKERRUNNER=$(id -u dockerrunner)
DOCKERFILES=$(getent group dockerfiles | cut -d: -f3)

echo "Created Users/groups:"
echo "dockeruser: $DOCKERUSER"
echo "dockerrunner: $DOCKERRUNNER"
echo "dockerfiles: $DOCKERFILES"
echo "Don't forget to add yourself to the dockerfiles group!"
echo "sudo usermod -aG dockerfiles <username>"