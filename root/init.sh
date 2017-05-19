#!/bin/sh

# Required
if [ -z ${DOMAIN+x} ]; then
    echo "[Error] Required parameters : DOMAIN"
    return;
fi

if [ -z ${CERTBOT_EMAIL+x} ]; then
    echo "[Error] Required parameters : CERTBOT_EMAIL"
    return;
fi

echo "Setup Nginx..."

# Enable AMP
cp /etc/nginx/conf.d/amp.conf.tpl /etc/nginx/conf.d/amp.conf
sed -i "s|{{DOMAIN}}|${DOMAIN}|g" /etc/nginx/conf.d/amp.conf

# [PRE]
# Ensure writable
sudo chmod 700 -R /etc/letsencrypt/archive

# Key exist?
# /etc/letsencrypt/live/$DOMAIN/fullchain.pem
# /etc/letsencrypt/live/$DOMAIN/privkey.pem
# We'll check only `fullchain.pem`
if [ ! -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem ]; then
  echo "[certbot] Init : $DOMAIN"
  docker exec -it $(docker ps -a -q --filter certbot/certbot) -n --agree-tos --renew-by-default --email "${CERTBOT_EMAIL}" --webroot -w ${ACME_WWWROOT:-/var/www/html} -d $DOMAIN -d www.$DOMAIN
  # docker run certbot/certbot certonly -n --agree-tos --renew-by-default --email "${CERTBOT_EMAIL}" --webroot -w ${ACME_WWWROOT:-/var/www/html} -d $DOMAIN -d www.$DOMAIN
else
  echo "[certbot] Already exist certificate, will skip init."
  ls /etc/letsencrypt/live/$DOMAIN
fi

# Enable SSL
cp /etc/nginx/conf.d/ssl.conf.tpl /etc/nginx/conf.d/ssl.conf
sed -i "s|{{DOMAIN}}|${DOMAIN}|g" /etc/nginx/conf.d/ssl.conf

# Diable default 80 config to let 443 apply.
mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disable

# Restart to take effect
sudo service nginx start && sudo nginx -t && sudo nginx -s reload

# [POST]
# Keep your private key secure by set the right permission so only you can read it at remote. 
sudo chmod 400 -R /etc/letsencrypt/archive

# Ensure read only.
sudo chmod 600 -R /etc/letsencrypt/archive /etc/letsencrypt/live/$DOMAIN/privkey.pem

# [CRON]
# Renewal, Add to daily cron
cp /root/renew.sh /etc/cron.daily/renew.sh

# Ensure excutable
chmod u+x /etc/cron.d/renew.sh