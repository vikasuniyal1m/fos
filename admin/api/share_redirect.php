<?php
/**
 * Legacy redirect — forwards to public share landing on fosmessenger.com
 */

$type = isset($_GET['type']) ? preg_replace('/[^a-zA-Z_-]/', '', $_GET['type']) : '';
$id = isset($_GET['id']) ? preg_replace('/[^0-9]/', '', $_GET['id']) : '';

if ($type !== '' && $id !== '') {
    header('Location: https://fosmessenger.com/share/' . strtolower($type) . '/' . $id, true, 301);
    exit;
}

header('Location: https://fosmessenger.com', true, 302);
exit;
