#!/bin/bash


while [ : ]
do
    printf "\nš updating channeltime...\n\n"
    docker-compose pull
    docker-compose up -d --remove-orphans
    printf "ā done updating\n sleeping 12h...\n"
   
    sleep 43200 #12h
done
