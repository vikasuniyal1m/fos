<?php
/**
 * Public share landing — https://fosmessenger.com/share/blog/123
 * App installed → opens app. Not installed → Play Store / App Store.
 */

$config = require __DIR__ . '/config.php';

$type = isset($_GET['type']) ? preg_replace('/[^a-zA-Z_-]/', '', $_GET['type']) : '';
$id = isset($_GET['id']) ? preg_replace('/[^0-9]/', '', $_GET['id']) : '';

if ($type === '' || $id === '') {
    $uri = $_SERVER['REQUEST_URI'] ?? '';
    if (preg_match('#/share/([^/]+)/([0-9]+)#i', $uri, $matches)) {
        $type = preg_replace('/[^a-zA-Z_-]/', '', $matches[1]);
        $id = preg_replace('/[^0-9]/', '', $matches[2]);
    }
}

$type = strtolower($type);
$id = (int) $id;

if ($type === '' || $id <= 0) {
    http_response_code(404);
    echo 'Link not found.';
    exit;
}

$appName = htmlspecialchars($config['app_name'], ENT_QUOTES, 'UTF-8');
$scheme = $config['app_scheme'];
$deepLink = "{$scheme}://share/{$type}/{$id}";
$playStore = $config['play_store_url'];
$appStore = $config['app_store_url'];
$androidPackage = $config['android_package'];

$userAgent = $_SERVER['HTTP_USER_AGENT'] ?? '';
$isIOS = (bool) preg_match('/iPad|iPhone|iPod/i', $userAgent);
$isAndroid = (bool) preg_match('/Android/i', $userAgent);
$storeUrl = $isIOS ? $appStore : $playStore;

$encodedFallback = rawurlencode($storeUrl);
$androidIntent = "intent://share/{$type}/{$id}#Intent;scheme={$scheme};package={$androidPackage};S.browser_fallback_url={$encodedFallback};end";

$labels = [
    'blog' => 'Blog Post',
    'prayer' => 'Prayer Request',
    'video' => 'Video',
    'photo' => 'Photo',
    'story' => 'Story',
    'testimony' => 'Testimony',
    'group' => 'Group',
];
$contentLabel = $labels[$type] ?? 'Content';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo $appName; ?> — <?php echo htmlspecialchars($contentLabel); ?></title>
    <meta name="description" content="Open this <?php echo htmlspecialchars(strtolower($contentLabel)); ?> in the <?php echo $appName; ?> app.">
    <meta property="og:title" content="<?php echo $appName; ?>">
    <meta property="og:description" content="Tap to open in the app or download free.">
    <meta property="og:type" content="website">
    <style>
        * { box-sizing: border-box; }
        body {
            margin: 0;
            min-height: 100vh;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(160deg, #FAF6EC 0%, #F0E8D8 100%);
            color: #5F4628;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
        }
        .card {
            width: 100%;
            max-width: 420px;
            background: #fff;
            border-radius: 24px;
            padding: 32px 28px;
            text-align: center;
            box-shadow: 0 12px 40px rgba(95, 70, 40, 0.12);
        }
        .logo {
            width: 72px;
            height: 72px;
            margin: 0 auto 16px;
            border-radius: 18px;
            background: #8B4513;
            color: #fff;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 34px;
        }
        h1 { font-size: 22px; margin: 0 0 8px; color: #3E2E1F; }
        p { margin: 0 0 24px; line-height: 1.5; color: #7A6548; font-size: 15px; }
        .loader {
            width: 36px; height: 36px; margin: 0 auto 20px;
            border: 4px solid #EDE4D4;
            border-top-color: #8B4513;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin { to { transform: rotate(360deg); } }
        .btn {
            display: block;
            width: 100%;
            padding: 14px 18px;
            margin-bottom: 12px;
            border-radius: 14px;
            text-decoration: none;
            font-weight: 600;
            font-size: 15px;
        }
        .btn-primary { background: #8B4513; color: #fff; }
        .btn-secondary { background: #FAF6EC; color: #5F4628; border: 1px solid #E8DCC8; }
        .hint { font-size: 13px; color: #9A8568; margin-top: 8px; }
    </style>
    <script>
        (function () {
            var deepLink = <?php echo json_encode($deepLink); ?>;
            var androidIntent = <?php echo json_encode($androidIntent); ?>;
            var storeUrl = <?php echo json_encode($storeUrl); ?>;
            var isAndroid = <?php echo $isAndroid ? 'true' : 'false'; ?>;
            var isIOS = <?php echo $isIOS ? 'true' : 'false'; ?>;

            function openApp() {
                var start = Date.now();
                if (isAndroid) {
                    window.location.href = androidIntent;
                } else {
                    window.location.href = deepLink;
                }
                setTimeout(function () {
                    if (Date.now() - start < 3500) {
                        window.location.href = storeUrl;
                    }
                }, 2500);
            }

            window.addEventListener('load', function () {
                setTimeout(openApp, 400);
            });
        })();
    </script>
</head>
<body>
    <div class="card">
        <div class="logo">🍇</div>
        <div class="loader" aria-hidden="true"></div>
        <h1><?php echo $appName; ?></h1>
        <p>Opening this <?php echo htmlspecialchars(strtolower($contentLabel)); ?> in the app…</p>

        <a class="btn btn-primary" href="<?php echo htmlspecialchars($deepLink); ?>">Open in App</a>
        <a class="btn btn-secondary" href="<?php echo htmlspecialchars($playStore); ?>">Get on Google Play</a>
        <a class="btn btn-secondary" href="<?php echo htmlspecialchars($appStore); ?>">Get on App Store</a>

        <p class="hint">No app? Download free — then open this link again.</p>
    </div>
</body>
</html>
