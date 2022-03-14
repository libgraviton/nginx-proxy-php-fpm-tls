<?php

if (!isset($_ENV['ENVIRONMENT_JSON_PREFIX'])) {
    echo "{}";
    exit(0);
}

$prefix = $_ENV['ENVIRONMENT_JSON_PREFIX'];
$env = [];

foreach ($_ENV as $key => $val) {
    if (strlen($key) > strlen($prefix) && substr($key, 0, strlen($prefix)) == $prefix && strpos($val, ';') > 0) {
        $parts = array_map('trim', explode(';', $val));
        if (count($parts) == 2 && !empty($parts[0])) {
            $env[$parts[0]] = $parts[1];
        }
    }
}

echo json_encode($env, JSON_UNESCAPED_SLASHES + JSON_PRETTY_PRINT).PHP_EOL;
