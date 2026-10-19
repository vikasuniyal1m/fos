<?php
/**
 * Legacy admin share URL → redirect to public fosmessenger.com share page.
 * Old: admin.fosmessenger.com/api/share/blog/123
 * New: fosmessenger.com/share/blog/123
 */

$type = isset($_GET['type']) ? preg_replace('/[^a-zA-Z_-]/', '', $_GET['type']) : '';
$id = isset($_GET['id']) ? preg_replace('/[^0-9]/', '', $_GET['id']) : '';

if ($type === '' || $id === '') {
    $uri = $_SERVER['REQUEST_URI'] ?? '';
    if (preg_match('#/share/([^/]+)/([0-9]+)#i', $uri, $matches)) {
        $type = preg_replace('/[^a-zA-Z_-]/', '', $matches[1]);
        $id = preg_replace('/[^0-9]/', '', $matches[2]);
    }
}

if ($type !== '' && $id !== '') {
    header('Location: https://fosmessenger.com/share/' . strtolower($type) . '/' . $id, true, 301);
    exit;
}

http_response_code(404);
echo 'Link not found.';
