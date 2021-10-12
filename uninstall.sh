#!/bin/bash

#    Copyright 2021 Leo Lox
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.



printf "\n\n"
read -p "❔ are you sure you want to delete channeltime and related data (db, files, certificates)? (y/N) " decision
if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    printf "🚫 abort\n"
    exit 1
fi

printf "ℹ shutting down ...\n"
docker-compose down
printf "✅ all services stopped\n\n"

printf "ℹ removing containers...\n"
docker-compose rm
printf "✅ done removing containers\n\n"

printf "ℹ removing userdata (db, files, certificates)...\n"
rm  -f ./data -R
printf "✅ done removing userdata\n\n"


printf "
██████████████████████████████████████████████████████████████████
██                                                              ██
██                                                              ██
██                                                              ██
██                                                              ██
██                           BYE 👋                             ██
██                                                              ██
██                                                              ██
██                                                              ██
██                                                              ██
██████████████████████████████████████████████████████████████████
\n"


