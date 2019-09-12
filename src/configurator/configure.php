<?php

require __DIR__.'/vendor/autoload.php';

use Twig\Environment;
use Twig\Loader\FilesystemLoader;

/**
 * for dev purposes
 */
/*
$_ENV = [
    'SERVERNAME' => 'localhost',
    'WORKER_PROCESSES' => 6,
    'WORKER_CONNECTIONS' => 1024,
    'KEEPALIVE_TIMEOUT' => 200,
    'CLIENT_BODY_BUFFER_SIZE' => '15M',
    'CLIENT_MAX_BODY_SIZE' => '15M',
    'GZIP_ENABLED' => 'on',
    'GZIP_TYPES' => 'text/html',
    'ENABLE_HTTP2' => 'true',
    'SSL_CERT' => '/certs/fullchain.crt',
    'SSL_CERT_KEY' => '/certs/fullchain.key',
    'RESOLVER' => 'none',
    'RESOLVER_VALID' => '30s',
    'PROXY_STANDARD_FORWARD_PROTO' => 'http',
    'PROXY_STANDARD_FORWARD_PORT' => '332',
    'CONDITIONAL_BASIC_AUTH_HEADER' => 'http_x_forwarded_for',
    'CONDITIONAL_BASIC_AUTH_REGEX' => '~172\..*',
    'EXPOSE_PATH' => "/",
    'FPM_STATIC_WEBROOT' => '/var/www',
    'FPM_STATUS_ALLOWED_NETWORK' => '172.*',

     'RULES_1' => '/consultation#GET',
     'RULES_2' => '/person/customer#GET',

    'VHOST_GRV_SERVERNAME' => 'grv',
     'VHOST_GRV_FPM_PATH' => '/var/www/vendor/graviton/graviton/web/app.php',
     'VHOST_GRV_FPM_UPSTREAM' => 'graviton',
    'VHOST_GRV_BASIC_USERNAME' => 'hans',
    'VHOST_GRV_BASIC_PASSWORD' => 'hans',

    'VHOST_GW_SERVERNAME' => 'gw',
    'VHOST_GW_FPM_PATH' => '/var/www/app.php',
    'VHOST_GW_FPM_UPSTREAM' => 'gateway',

    'VHOST_G2_SERVERNAME' => 'g2',
    'VHOST_G2_PROXY_URL' => 'http://upddd',
    'VHOST_G2_BASIC_USERNAME' => 'hans',
    'VHOST_G2_BASIC_PASSWORD' => 'hans',
    'VHOST_G2_EXPOSE_PATH' => '/derDude',

    'VHOST_G3_SERVERNAME' => 'g2',
    'VHOST_G3_DEFAULT_SERVE' => '/var/www/hans',

    'ENABLE_CONDITIONAL_BASIC_AUTH' =>"NO",

];
*/
// END FOR DEV

$outputFile = null;
if (isset($argv[1])) {
    $outputFile = $argv[1];
}

/**** PREPARE VHOSTS ARRAY
 * we either accept 1 vhost configured (no VHOST_ prefix necessary)
 * or multiple vhosts configured by VHOST_[NAME]_*.
 * for our template we always prepare a nice array for the sub template
 */

$vhostPrefix = 'VHOST_';
$vhosts = [];
foreach ($_ENV as $envName => $envValue) {
    if (substr($envName, 0, strlen($vhostPrefix)) == $vhostPrefix) {
        $nameParts = explode('_', $envName);
        if (count($nameParts) < 3) {
            echo 'ERROR ON ENV "'.$envName.'" => not matching naming convention, skipping...'.PHP_EOL;
            continue;
        }

        $vhosts[$nameParts[1]][implode('_', array_slice($nameParts, 2))] = $envValue;
        unset($_ENV[$envName]);
    }
}

// any vhosts set? if not -> fill with default
if (empty($vhosts)) {
    $_ENV['VHOSTS']['default'] = $_ENV;
} else {
    $_ENV['VHOSTS'] = $vhosts;
}

/***** DO STUFF PER VHOST *****/

foreach ($_ENV['VHOSTS'] as $vhostName => $vhostSettings) {
    // basic auth?
    if (isset($vhostSettings['BASIC_USERNAME']) && isset($vhostSettings['BASIC_PASSWORD'])) {
        // create basic auth file
        $passwdFile = '/tmp/nginx_passwd_vhost_'.$vhostName;
        shell_exec(
            sprintf(
                'htpasswd -bc %s %s %s',
                escapeshellarg($passwdFile),
                escapeshellarg($vhostSettings['BASIC_USERNAME']),
                escapeshellarg($vhostSettings['BASIC_PASSWORD'])
            )
        );
        $vhostSettings['BASIC_AUTH_FILE'] = $passwdFile;
    }

    // is conditional basic auth enabled somewhere? -> toggle for global map()
    if (isset($vhostSettings['ENABLE_CONDITIONAL_BASIC_AUTH']) && $vhostSettings['ENABLE_CONDITIONAL_BASIC_AUTH'] == 'YES') {
        $_ENV['CONDITIONAL_BASIC_AUTH_USED'] = true;
    }

    // proxy mode fpm?
    if (isset($vhostSettings['FPM_UPSTREAM']) && isset($vhostSettings['FPM_PATH'])) {
        $vhostSettings['PROXY_MODE'] = 'fpm';
        $_ENV['GLOBAL_UPSTREAMS'][$vhostName] = $vhostSettings['FPM_UPSTREAM'];
    }

    if (isset($vhostSettings['PROXY_URL'])) {
        $vhostSettings['PROXY_MODE'] = 'standard';
        $_ENV['GLOBAL_UPSTREAMS'][$vhostName] = $vhostSettings['PROXY_URL'];
    }

    $envCopy = $_ENV;
    if (isset($envCopy['VHOSTS'])) unset($envCopy['VHOSTS']);

    $fullArray = array_merge($envCopy, $vhostSettings);
    $fullArray['LOCATION_RULES'] = getLocationRules($fullArray);

    $_ENV['VHOSTS'][$vhostName] = $fullArray;
}

/***** END DO STUFF PER VHOST ****/

/***** RESOLVER PREPARATION *****/

if ($_ENV['RESOLVER'] == 'none') {
    // read out from resolv.conf
    $_ENV['RESOLVER'] = getResolvers();
}

echo 'configuration: '.PHP_EOL;
print_r($_ENV);

/******* END OF ALL *******/

$environment = array_merge($_ENV, []);

$loader = new FilesystemLoader(__DIR__.'/templates');
$twig = new Environment($loader, []);

$mainTemplate = 'main.twig';
if (is_null($outputFile)) {
    echo $twig->render($mainTemplate, $environment);
} else {
    file_put_contents($outputFile, $twig->render($mainTemplate, $environment));
    echo 'wrote configuration to '.$outputFile.PHP_EOL;
}

function getResolvers() {
    $resolver = file_get_contents('/etc/resolv.conf');

    echo '--------------- RESOLV ------------'.PHP_EOL;
    echo $resolver;
    echo '--------------- END RESOLV ------------'.PHP_EOL;

    preg_match_all('/nameserver (.*)/', $resolver, $matches);

    if (empty($matches[1])) {
        echo 'ERROR - COULD NOT DETERMINE RESOLVERS! PLEASE SET ENV "RESOLVER"!';
        die;
    }

    return implode(' ', $matches[1]);
}

function getLocationRules($vhostSettings) {
    $rules = [];
    foreach ($vhostSettings as $key => $val) {
        if (substr($key, 0, 6) == 'RULES_') {
            $parts = explode('#', $val);
            $rules[] = [
                'path' => $parts[0],
                'method' => $parts[1]
            ];
        }
    }
    return $rules;
}
