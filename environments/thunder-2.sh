#!/bin/bash
# @file
# Thunder 2 environment variables and functions.

function drupal_ti_install_drupal() {
    composer create-project burdamagazinorg/thunder-project . --stability dev --no-interaction --no-install
	composer install
    cd docroot
	php -d sendmail_path=$(which true) ~/.composer/vendor/bin/drush.php --yes -v site-install "$DRUPAL_TI_INSTALL_PROFILE" --db-url="$DRUPAL_TI_DB_URL" thunder_module_configure_form.install_modules_thunder_demo
	drush use $(pwd)#default
}

function drupal_ti_clear_caches() {
	drush cr
}

#
# Ensures that the module is linked into the Drupal code base.
#
function drupal_ti_ensure_module_linked() {
	# Ensure we are in the right directory.
	cd "$DRUPAL_TI_DRUPAL_BASE"

	# This function is re-entrant.
	if [ -L "$DRUPAL_TI_DRUPAL_DIR/$DRUPAL_TI_MODULES_PATH/$DRUPAL_TI_MODULE_NAME" ]
	then
		return
	fi

  # Explicitly set the repository as 0 and 1 override the default repository as
  # the local repository must be the first in the list.
	composer config repositories.0 path $TRAVIS_BUILD_DIR
	composer config repositories.1 composer https://packages.drupal.org/8
	composer require drupal/$DRUPAL_TI_MODULE_NAME *@dev
}

#
# Run a webserver and wait until it is started up.
#
function drupal_ti_run_server() {
	# This function is re-entrant.
	if [ -r "$TRAVIS_BUILD_DIR/../drupal_ti-drush-server-running" ]
	then
		return
	fi

	# Use hhvm_serve for PHP 5.3 fcgi and hhvm fcgi
	PHP_VERSION=$(phpenv version-name)
	if [ "$PHP_VERSION" = "5.3" -o "$PHP_VERSION" = "hhvm" ]
	then
		export GOPATH="$DRUPAL_TI_DIST_DIR/go"
		export DRUPAL_TI_WEBSERVER_HOST=$(echo "$DRUPAL_TI_WEBSERVER_URL" | sed 's,http://,,')
		{ "$GOPATH/bin/hhvm-serve" -listen="$DRUPAL_TI_WEBSERVER_HOST:$DRUPAL_TI_WEBSERVER_PORT" 2>&1 | drupal_ti_log_output "webserver" ; } &
	else
		# start a web server on port 8080, run in the background; wait for initialization
		{ drush runserver "$DRUPAL_TI_WEBSERVER_URL:$DRUPAL_TI_WEBSERVER_PORT" 2>&1 | drupal_ti_log_output "webserver" ; } &
	fi

	# Wait until drush server has been started.
	drupal_ti_wait_for_service_port "$DRUPAL_TI_WEBSERVER_PORT"
	touch "$TRAVIS_BUILD_DIR/../drupal_ti-drush-server-running"
}

export DRUPAL_TI_DRUSH_VERSION="drush/drush:8.1.*"
export DRUPAL_TI_SIMPLETEST_FILE="core/scripts/run-tests.sh"
export DRUPAL_TI_DRUPAL_BASE="$TRAVIS_BUILD_DIR/../thunder-2"
export DRUPAL_TI_DRUPAL_DIR="$DRUPAL_TI_DRUPAL_BASE/docroot"
export DRUPAL_TI_DIST_DIR="$HOME/.dist"
export PATH="$DRUPAL_TI_DIST_DIR/usr/bin:$PATH"
if [ -z "$DRUPAL_TI_CORE_BRANCH" ]
then
	export DRUPAL_TI_CORE_BRANCH="8.4.x"
fi

export DRUPAL_TI_MODULES_PATH="modules/contrib"

# Display used for running selenium browser.
export DISPLAY=:99.0

# export SIMPLETEST_DB for KernelTestBase, so it is available for all runners.
export SIMPLETEST_DB="$DRUPAL_TI_DB_URL"

# export SIMPLETEST_BASE_URL for BrowserTestBase, so it is available for all runners.
export SIMPLETEST_BASE_URL="$DRUPAL_TI_WEBSERVER_URL:$DRUPAL_TI_WEBSERVER_PORT"

# Use 'thunder' by default for Thunder.
if [ -z "$DRUPAL_TI_INSTALL_PROFILE" ]
then
	export DRUPAL_TI_INSTALL_PROFILE="thunder"
fi
