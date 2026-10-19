<?php
declare(strict_types=1);

/**
 * API smoke test runner for all endpoints in this folder.
 *
 * Usage:
 * - Browser: /admin/api/test_all_apis.php
 * - CLI: php admin/api/test_all_apis.php
 */

$apiRoot = __DIR__;
$selfFile = basename(__FILE__);
$isCli = PHP_SAPI === 'cli';

if (!$isCli) {
    header('Content-Type: text/html; charset=utf-8');
}

/**
 * Print output safely for CLI and browser.
 */
function out(string $line = '', bool $escapeHtml = true): void
{
    global $isCli;

    if ($isCli) {
        echo $line . PHP_EOL;
        return;
    }

    echo $escapeHtml ? htmlspecialchars($line, ENT_QUOTES, 'UTF-8') : $line;
    echo "<br>\n";
}

/**
 * Build endpoint URL based on current host/protocol.
 */
function buildUrl(string $relativePath): string
{
    if (PHP_SAPI === 'cli') {
        return 'http://localhost/' . ltrim($relativePath, '/');
    }

    $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || (isset($_SERVER['SERVER_PORT']) && (int)$_SERVER['SERVER_PORT'] === 443);
    $scheme = $https ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';

    return $scheme . '://' . $host . '/' . ltrim($relativePath, '/');
}

/**
 * Discover API PHP files recursively.
 */
function discoverApiFiles(string $apiRoot, string $selfFile): array
{
    $files = [];
    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($apiRoot, FilesystemIterator::SKIP_DOTS)
    );

    foreach ($iterator as $fileInfo) {
        if (!$fileInfo->isFile()) {
            continue;
        }

        if (strtolower($fileInfo->getExtension()) !== 'php') {
            continue;
        }

        $fileName = $fileInfo->getFilename();
        if ($fileName === $selfFile) {
            continue;
        }

        // Skip non-endpoint helpers/migrations.
        if (preg_match('/^(auth-helper|migrate_.*|add_.*_column|test.*)\.php$/i', $fileName)) {
            continue;
        }

        $absolute = $fileInfo->getPathname();
        $relative = str_replace('\\', '/', substr($absolute, strlen($apiRoot) + 1));

        $files[] = [
            'absolute' => $absolute,
            'relative' => $relative,
        ];
    }

    usort($files, static function (array $a, array $b): int {
        return strcmp($a['relative'], $b['relative']);
    });

    return $files;
}

/**
 * Execute a GET request and return status + response.
 */
function hitEndpoint(string $url): array
{
    $ch = curl_init($url);

    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT => 12,
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_USERAGENT => 'FOS-API-SmokeTest/1.0',
    ]);

    $response = curl_exec($ch);
    $error = curl_error($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    return [
        'ok' => $error === '',
        'status' => $status,
        'error' => $error,
        'response' => is_string($response) ? trim($response) : '',
    ];
}

$apiFiles = discoverApiFiles($apiRoot, $selfFile);

if (!$isCli) {
    out('<h2>FOS API Smoke Test</h2>', false);
}

out('Scanning folder: ' . $apiRoot);
out('Endpoints found: ' . count($apiFiles));
out(str_repeat('-', 70));

$successCount = 0;
$warningCount = 0;
$errorCount = 0;

foreach ($apiFiles as $api) {
    $relativePath = 'admin/api/' . $api['relative'];
    $url = buildUrl($relativePath);
    $result = hitEndpoint($url);

    if (!$result['ok']) {
        $errorCount++;
        out('[ERROR] ' . $api['relative'] . ' | cURL: ' . $result['error']);
        continue;
    }

    if ($result['status'] >= 200 && $result['status'] < 400) {
        $successCount++;
        out('[OK]    ' . $api['relative'] . ' | HTTP ' . $result['status']);
    } else {
        $warningCount++;
        $preview = mb_substr($result['response'], 0, 120);
        out('[WARN]  ' . $api['relative'] . ' | HTTP ' . $result['status'] . ' | ' . $preview);
    }
}

out(str_repeat('-', 70));
out('Done.');
out('Success: ' . $successCount . ' | Warnings: ' . $warningCount . ' | Errors: ' . $errorCount);
out('Note: Some endpoints require POST body/auth and may return warnings by design.');

