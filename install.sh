#!/bin/bash

nextcloud_url='http://example.com' # Full URL of NextCloud instance
nextcloud_version='16.0.3' # Desired NextCloud version
db_root_password='supersecret' # MySQL database root password
db_user_password='secret' # MySQL database user password
datapath='/cloudData' # Path for user data to be stored

# DO NOT EDIT BELOW THIS LINE

ocpath='/var/www/nextcloud' # Path for NextCloud to be installed
htuser='www-data' # User Apache runs as 
htgroup='www-data' # Group Apache runs as
rootuser='root'

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Update Repositories and Install Packages

# Add PHP 7.1 Repository
add-apt-repository ppa:ondrej/php -y
apt-get update

# Install Apache, Redis and PHP extensions
apt-get install apache2 -y
apt-get install php7.1 php7.1-curl php7.1-gd php7.1-fpm php7.1-cli php7.1-opcache php7.1-mbstring php7.1-xml php7.1-zip libapache2-mod-php7.2 -y
apt-get install redis-server php-redis -y

# Install MySQL database server
export DEBIAN_FRONTEND="noninteractive"
debconf-set-selections <<< "mysql-server mysql-server/root_password password $db_root_password"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $db_root_password"
apt-get install mysql-server php7.1-mysql -y

# Enable Apache extensions
a2enmod proxy_fcgi setenvif
a2enconf php7.0-fpm
service apache2 reload
apt-get install libxml2-dev php7.1-zip php7.1-xml php7.1-gd php7.1-curl php7.1-mbstring -y
a2enmod rewrite
service apache2 reload

# Download Nextcloud into web directory
printf '<meta http-equiv="refresh" content="0;URL='"'""$nextcloud_url"'/nextcloud'"'"'" />' > /var/www/html/index.html
wget https://download.nextcloud.com/server/releases/nextcloud-$nextcloud_version.zip
apt-get install unzip -y
unzip nextcloud-$nextcloud_version.zip -d /var/www
rm nextcloud-$nextcloud_version.zip

# Create data directory if does not exist yet
mkdir -p $datapath

# Set file and folder permissions
printf "Creating possible missing Directories\n"
mkdir -p $ocpath/data
mkdir -p $ocpath/assets
mkdir -p $ocpath/updater

printf "chmod Files and Directories\n"
find ${ocpath}/ -type f -print0 | xargs -0 chmod 0640
find ${ocpath}/ -type d -print0 | xargs -0 chmod 0750

printf "chown Directories\n"
chown -R ${rootuser}:${htgroup} ${ocpath}/
chown -R ${htuser}:${htgroup} ${ocpath}/apps/
chown -R ${htuser}:${htgroup} ${ocpath}/assets/
chown -R ${htuser}:${htgroup} ${ocpath}/config/
chown -R ${htuser}:${htgroup} ${ocpath}/data/
chown -R ${htuser}:${htgroup} ${datapath}/
chown -R ${htuser}:${htgroup} ${ocpath}/themes/
chown -R ${htuser}:${htgroup} ${ocpath}/updater/
chown -R ${htuser}:${htgroup} /tmp
chmod +x ${ocpath}/occ

printf "chmod/chown .htaccess\n"
if [ -f ${ocpath}/.htaccess ]
then
 chmod 0644 ${ocpath}/.htaccess
 chown ${rootuser}:${htgroup} ${ocpath}/.htaccess
fi

if [ -f ${ocpath}/data/.htaccess ]
then
 chmod 0644 ${ocpath}/data/.htaccess
 chown ${rootuser}:${htgroup} ${ocpath}/data/.htaccess
fi

# Configure Apache
touch /etc/apache2/sites-available/nextcloud.conf
printf "Alias /nextcloud "/var/www/nextcloud/"\n\n<Directory /var/www/nextcloud/>\n Options +FollowSymlinks\n AllowOverride All\n\n<IfModule mod_dav.c>\n Dav off\n</IfModule>\n\nSetEnv HOME /var/www/nextcloud\nSetEnv HTTP_HOME /var/www/nextcloud\n\n</Directory>" > /etc/apache2/sites-available/nextcloud.conf
ln -s /etc/apache2/sites-available/nextcloud.conf /etc/apache2/sites-enabled/nextcloud.conf
a2enmod headers
a2enmod env
a2enmod dir
a2enmod mime
service apache2 reload

# Configure MySQL database
mysql -uroot -p$db_root_password <<QUERY_INPUT
CREATE DATABASE nextcloud;
CREATE USER 'nextclouduser'@'localhost' IDENTIFIED BY '$db_user_password';
GRANT ALL PRIVILEGES ON nextcloud.* TO nextclouduser@localhost;
FLUSH PRIVILEGES;
EXIT
QUERY_INPUT

# Enable NextCloud cron job every 15 minutes
crontab -u www-data -l > cron
echo "*/15  *  *  *  * php -f /var/www/nextcloud/cron.php" >> cron
crontab -u www-data cron
rm cron

# Install complete
printf "\n\nInstall complete.\nNavigate to your NextCloud instance in a web browser to complete the setup wizard, before you run the optimization script.\n\n"
