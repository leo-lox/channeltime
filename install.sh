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





# 😲 you here? thats uncommon...

#load config.env
if [ -e config.env ]
then
  set -a
  source config.env
  set +a
  exec $@
else
  printf "\n⛔ config.env missing\n"
  printf "➡ check if config.env exists and check if its in the right place (same as install.sh)\n"
  exit 1
fi


if [ "$CHANNELTIMELICENCEACCEPT" != "true" ]; then
  printf '\n⛔ licence not accepted, read the licence and set LICENCEACCEPT to true (in config.env)\n'
  exit 1
fi


if ! [ -x "$(command -v docker-compose)" ]; then
  printf '\n⛔ error: docker-compose is not installed.\n' >&2
  exit 1
fi


printf "\nchanneling energy⚡⚡⚡... done\n\n\n"


#create jwt crt

if [ -d "./data/jwt" ]; then
  read -p "❔ existing gateway certificate found. Replace existing certificate? ♻ (y/N) (not recommended) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    printf "⏩ skipping gateway certificate\n"
  else
    openssl genrsa -out ./data/jwt/key.pem 4096
    openssl rsa -in ./data/jwt/key.pem -outform PEM -pubout -out ./data/jwt/public.pem
    printf ℹ gateway certificate overwritten 
  fi
else
  mkdir -p "./data/jwt"
  openssl genrsa -out ./data/jwt/key.pem 4096
  openssl rsa -in ./data/jwt/key.pem -outform PEM -pubout -out ./data/jwt/public.pem
  printf "✅ created gateway certificate\n"
fi




# create config
if [ -e "./data/nginx/app.conf" ]; then
  printf "⏩ nginx configuration already exists, skipping...\n"
else
  mkdir -p "./data/nginx"
cat <<EOF >./data/nginx/app.conf
server {
    listen 80;
    server_name ${CTDOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location /imprint {
        return 301 ${CTIMPRINTURL};
    }
    
    location /legal {
        return 301 ${CTLEGALURL};
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}
server {
    listen 443 ssl;
    server_name ${CTDOMAIN};

    ssl_certificate /etc/letsencrypt/live/${CTDOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${CTDOMAIN}/privkey.pem;

    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    root /usr/share/nginx/html;
    gzip on;
    gzip_types text/css application/javascript application/json image/svg+xml;
    gzip_comp_level 9;
    etag on;
    

    location /imprint {
        return 301 ${CTIMPRINTURL};
    }

    location /legal {
        return 301 ${CTLEGALURL};
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /assets/ {
    add_header Cache-Control max-age=31536000;
    }

    location /index.html {
      add_header Cache-Control no-cache;
    }

    location /config.json {
      add_header Cache-Control no-cache;
    }
}
EOF
 
  printf "✅ created nginx configuration\n"
fi




# dummy certificate
# 😕 I know its stupid isn't it? 

domains=($CTDOMAIN www.$CTDOMAIN)
rsa_key_size=4096
data_path="./data/certbot"
email=$LETSENCRYPTMAIL # Adding a valid address is strongly recommended
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits


if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  printf "ℹ Downloading recommended TLS parameters ...\n"
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  printf "✅ installed TLS parameters\n"
fi


if [ -d "$data_path/conf/live/$domains" ]; then
  printf "⏩ certificate already exists skipping dummy certificate\n"
  else
    printf "ℹ Creating dummy certificate for $domains ...\n"
    path="/etc/letsencrypt/live/$domains"
    mkdir -p "$data_path/conf/live/$domains"
    docker-compose run --rm --entrypoint "\
    openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
      -keyout '$path/privkey.pem' \
      -out '$path/fullchain.pem' \
      -subj '/CN=localhost'" certbot
    printf "✅ dummy certificate created\n"
fi


# lets take a break... here is a 🍪 for you 😊


# starting up
tput setaf 3; printf "\nℹ starting up... please be patient\n\n"
tput init
docker-compose up -d

printf "\n\n✅ here we go 💪\n"


# lets encrypt
printf "\n"
read -p "❔ do you want a letsencrypt certificate for $domains? (recommended) (y/N) " decision
if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
  exit
fi



printf "ℹ deleting dummy certificate for $domains ...\n"
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
printf "\n"



printf "ℹ requesting Let's Encrypt certificate for $domains ...\n"
#Join $domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
printf "✅ letsencrypt certificate\n"


# reload to apply/load new certificate

printf "ℹ reloading nginx ...\n"
docker-compose exec nginx nginx -s reload
printf "✅ done reloading nginx\n\n"


printf "ℹ reloading gateway ...\n"
docker-compose restart gateway
printf "✅ done reloading gateway\n\n"

printf "ℹ reloading voice ...\n"
docker-compose restart voice
printf "✅ done reloading voice\n\n"


printf "\n\n"
tput setaf 2;
printf "🎉 installation complete head over to https://${CTDOMAIN} 🎉\n"
tput init

# print operator token
docker logs channeltime-gateway


# 🤔 looks good to you?