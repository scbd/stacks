# set host names

docker swarm init

while true; do
    read -p "Would you like to reload your docker secrets? (Y or N)
    Drupal-docker requires secrets, if this is your first time initializing.  Choose yes.
     " yn
    case $yn in
        [Yy]* ) $(tput sgr0); sh ../secrets.sh; break;;
        [Nn]* ) $(tput sgr0); break;;
        * ) echo "Please answer yes or no.";;
    esac
done

while true; do
    read -p "Would you like to bring up dependent stacks PROXY && MANAGE? (Y or N)
    If this is your first tim initializing drupal choose yes.
     " yn
    case $yn in
        [Yy]* ) $(tput sgr0); pushd ../proxy; sh init.sh; popd; pushd ../manage; sh init.sh; popd; break;;
        [Nn]* ) $(tput sgr0); break;;
        * ) echo "Please answer yes or no.";;
    esac
done
echo
echo $('pwd')
docker volume create db-data
docker volume create cron-data
docker volume create webgrind
docker volume create docker-sync-drupal
docker volume create docker-sync-drupal-config
docker network create --driver overlay --subnet 10.0.12.0/24 --opt encrypted=true drupal
nohup docker-sync start &
docker stack deploy -c drupal.yml DRUPAL

sh ./wait-for-it.sh localhost:3306 --timeout=0 --strict -- echo "SQL is running"
echo "Wiating for SQL initialization ....."
sleep 5s
sh ./init-db.sh
echo "SQL initialized"

echo "INstalling composer packages"
docker exec -ti DRUPAL_php.1.$(docker service ps -f 'name=DRUPAL_php.1' DRUPAL_php -q) bash -c " composer install"

echo "Wiating for php container to impliment pachage security check ....."
sleep 5s
docker exec -ti DRUPAL_php.1.$(docker service ps -f 'name=DRUPAL_php.1' DRUPAL_php -q) php /var/www/html/sh/actions/security-checker.phar security:check composer.lock

echo "Import Config"
sleep 5s
docker exec -ti DRUPAL_php.1.$(docker service ps -f 'name=DRUPAL_php.1' DRUPAL_php -q)  bash -c "drush -r /var/www/html/web -y cim"
docker exec -ti DRUPAL_php.1.$(docker service ps -f 'name=DRUPAL_php.1' DRUPAL_php -q)  bash -c "drush -r /var/www/html/web -y updatedb"
docker exec -ti DRUPAL_php.1.$(docker service ps -f 'name=DRUPAL_php.1' DRUPAL_php -q)  bash -c "drush -r /var/www/html/web -y entup"
docker exec -ti DRUPAL_php.1.$(docker service ps -f 'name=DRUPAL_php.1' DRUPAL_php -q)  bash -c "drush -r /var/www/html/web -y cr drush"

echo "drupal ready"
