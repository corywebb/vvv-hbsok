#!/usr/bin/env bash
# Provision WordPress Stable

SLC_API_KEY=`get_config_value 'SLC_API_KEY'`
DOMAIN=`get_primary_host "${VVV_SITE_NAME}".dev`
WP_VERSION=`get_config_value 'wp_version' 'latest'`
SITE_TITLE="HBS Open Knowledge"
DB_NAME="hbsok"

# Configure SSH known hosts
# So we can access private github repos.
noroot mkdir -p /home/vagrant/.ssh
noroot touch /home/vagrant/.ssh/known_hosts
if ! noroot grep -Fxq "github.com" /home/vagrant/.ssh/known_hosts; then
  noroot ssh-keyscan -t dsa,rsa github.com >> /home/vagrant/.ssh/known_hosts 2>/dev/null
  echo "Success: Added host to SSH known_hosts for user 'vagrant': github.com"
fi

# Make a database, if we don't already have one
echo -e "\nCreating database '${DB_NAME}' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

# Nginx Logs
mkdir -p ${VVV_PATH_TO_SITE}/log
touch ${VVV_PATH_TO_SITE}/log/error.log
touch ${VVV_PATH_TO_SITE}/log/access.log

# Install and configure the latest stable version of WordPress
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-load.php" ]]; then
  echo "Downloading WordPress..."
	noroot wp core download --version="${WP_VERSION}"
fi

if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-config.php" ]]; then
  echo "Configuring WordPress Stable..."
  noroot wp core config --dbname="${DB_NAME}" --dbuser=wp --dbpass=wp --quiet --extra-php <<PHP
define( 'WP_DEBUG', true );
if ( WP_DEBUG ) {
  define( 'WP_DEBUG_LOG', true );
  define( 'WP_DEBUG_DISPLAY', false );
  define( 'SAVEQUERIES', true );
  define( 'SCRIPT_DEBUG', true );
  @ini_set( 'display_errors', 0 );
  if ( function_exists( 'xdebug_disable' ) ) {
    // xdebug_disable();
  }
}

define( 'WP_ALLOW_MULTISITE', true );
define('MULTISITE', true);
define('SUBDOMAIN_INSTALL', true);
$base = '/';
define('DOMAIN_CURRENT_SITE', 'ok.hbs.dev');
define('PATH_CURRENT_SITE', '/');
define('SITE_ID_CURRENT_SITE', 1);
define('BLOG_ID_CURRENT_SITE', 1);
define('SUNRISE', true);
define('FORCE_SSL_ADMIN', true);
define( 'NOBLOGREDIRECT', 'https://ok.hbs.dev/' );

define( 'WPMDB_LICENCE', '9372c6f2-2342-435b-a88a-6f557f775fd5' );
define( 'WPAI_LICENSE_KEY', 'f3c87ccaabdeeecd28227e840f78bad4' );

/* Mailgun Settings */
define( 'MAILGUN_USEAPI', true );
define( 'MAILGUN_APIKEY', 'key-1e4365119df55638e9a9c0566acdf76c' );
define( 'MAILGUN_DOMAIN', 'digital.hbs.org' );
define( 'MAILGUN_SECURE', true );
PHP
fi

plugins=(
  akismet
  basic-user-avatars
  cmb2
  force-strong-passwords
  google-analytics-for-wordpress
  limit-login-attempts
  mailgun
  posts-to-posts
  safe-svg
  stop-emails
  strong-password-generator
  term-management-tools
  theme-my-login
  user-switching
)

function update_plugins {
  for i in ${plugins[@]}; do
      if ! $(noroot wp plugin is-installed ${i}); then
        echo "Installing plugin: ${i}"
        noroot wp plugin install ${i} --activate-network --path="${VVV_PATH_TO_SITE}/public_html"
      else
        echo "Updating plugin: ${i}"
        noroot wp plugin update --path="${VVV_PATH_TO_SITE}/public_html" ${i}
      fi
  done
}

if ! $(noroot wp core is-installed); then
  echo "Installing WordPress Stable..."

  noroot wp core multisite-install --subdomains --url="${DOMAIN}" --quiet --title="${SITE_TITLE}" --admin_name=admin --admin_email="admin@local.test" --admin_password="password"

  echo "Adding hbsok repo and submodules..."
  cd ${VVV_PATH_TO_SITE}/public_html
  noroot git init .
  noroot git remote add origin git@github.com:reaktivstudios/hbs-ok.git
  noroot git fetch origin
  noroot git checkout -b master --track origin/master
  noroot git submodule update --init --recursive
  noroot git checkout -b develop --track origin/develop
  noroot git checkout master

  cd wp-content/themes/hbs-ck
  HOME=/home/vagrant noroot npm install
  noroot bower install
  noroot grunt build

  cd ../../plugins/hbs-ck-assignments
  noroot composer install
  HOME=/home/vagrant noroot npm install
  noroot grunt build

  echo "Installing .org plugins..."
  update_plugins

  echo "Deactivating mailgun..."
  noroot wp plugin deactivate --network mailgun
else
  echo "Updating WordPress Stable..."
  cd ${VVV_PATH_TO_SITE}/public_html
  noroot wp core update --version="${WP_VERSION}"

  noroot git submodule update --init --recursive

  update_plugins

  echo "Deactivating mandrill..."
  noroot wp plugin deactivate --network mailgun
fi
