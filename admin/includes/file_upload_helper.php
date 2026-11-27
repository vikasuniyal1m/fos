<?php
/**
 * File Upload Helper
 * Handles: Image compression, Video thumbnail generation, File optimization
 */

/**
 * Compress and optimize image
 * 
 * @param string $sourcePath Source image path
 * @param string $destinationPath Destination path (optional)
 * @param int $quality JPEG quality (1-100)
 * @param int $maxWidth Maximum width
 * @param int $maxHeight Maximum height
 * @return string|false Optimized image path or false on failure
 */
function compressImage($sourcePath, $destinationPath = null, $quality = 85, $maxWidth = 1920, $maxHeight = 1080) {
    if (!file_exists($sourcePath)) {
        return false;
    }
    
    $imageInfo = getimagesize($sourcePath);
    if (!$imageInfo) {
        return false;
    }
    
    $mimeType = $imageInfo['mime'];
    $originalWidth = $imageInfo[0];
    $originalHeight = $imageInfo[1];
    
    // Calculate new dimensions
    $ratio = min($maxWidth / $originalWidth, $maxHeight / $originalHeight, 1);
    $newWidth = intval($originalWidth * $ratio);
    $newHeight = intval($originalHeight * $ratio);
    
    // Create image resource
    switch ($mimeType) {
        case 'image/jpeg':
            $sourceImage = imagecreatefromjpeg($sourcePath);
            break;
        case 'image/png':
            $sourceImage = imagecreatefrompng($sourcePath);
            break;
        case 'image/gif':
            $sourceImage = imagecreatefromgif($sourcePath);
            break;
        case 'image/webp':
            $sourceImage = imagecreatefromwebp($sourcePath);
            break;
        default:
            return false;
    }
    
    if (!$sourceImage) {
        return false;
    }
    
    // Create new image
    $newImage = imagecreatetruecolor($newWidth, $newHeight);
    
    // Preserve transparency for PNG and GIF
    if ($mimeType === 'image/png' || $mimeType === 'image/gif') {
        imagealphablending($newImage, false);
        imagesavealpha($newImage, true);
        $transparent = imagecolorallocatealpha($newImage, 255, 255, 255, 127);
        imagefilledrectangle($newImage, 0, 0, $newWidth, $newHeight, $transparent);
    }
    
    // Resize
    imagecopyresampled($newImage, $sourceImage, 0, 0, 0, 0, $newWidth, $newHeight, $originalWidth, $originalHeight);
    
    // Determine output path
    if (!$destinationPath) {
        $pathInfo = pathinfo($sourcePath);
        $destinationPath = $pathInfo['dirname'] . '/' . $pathInfo['filename'] . '_compressed.' . $pathInfo['extension'];
    }
    
    // Save compressed image
    $success = false;
    switch ($mimeType) {
        case 'image/jpeg':
            $success = imagejpeg($newImage, $destinationPath, $quality);
            break;
        case 'image/png':
            $success = imagepng($newImage, $destinationPath, 9);
            break;
        case 'image/gif':
            $success = imagegif($newImage, $destinationPath);
            break;
        case 'image/webp':
            $success = imagewebp($newImage, $destinationPath, $quality);
            break;
    }
    
    imagedestroy($sourceImage);
    imagedestroy($newImage);
    
    return $success ? $destinationPath : false;
}

/**
 * Generate thumbnail from image
 * 
 * @param string $sourcePath Source image path
 * @param string $thumbnailPath Thumbnail path
 * @param int $width Thumbnail width
 * @param int $height Thumbnail height
 * @return string|false Thumbnail path or false on failure
 */
function generateThumbnail($sourcePath, $thumbnailPath, $width = 300, $height = 300) {
    if (!file_exists($sourcePath)) {
        return false;
    }
    
    $imageInfo = getimagesize($sourcePath);
    if (!$imageInfo) {
        return false;
    }
    
    $mimeType = $imageInfo['mime'];
    $originalWidth = $imageInfo[0];
    $originalHeight = $imageInfo[1];
    
    // Calculate crop dimensions (center crop)
    $ratio = max($width / $originalWidth, $height / $originalHeight);
    $cropWidth = intval($width / $ratio);
    $cropHeight = intval($height / $ratio);
    $cropX = intval(($originalWidth - $cropWidth) / 2);
    $cropY = intval(($originalHeight - $cropHeight) / 2);
    
    // Create image resource
    switch ($mimeType) {
        case 'image/jpeg':
            $sourceImage = imagecreatefromjpeg($sourcePath);
            break;
        case 'image/png':
            $sourceImage = imagecreatefrompng($sourcePath);
            break;
        case 'image/gif':
            $sourceImage = imagecreatefromgif($sourcePath);
            break;
        case 'image/webp':
            $sourceImage = imagecreatefromwebp($sourcePath);
            break;
        default:
            return false;
    }
    
    if (!$sourceImage) {
        return false;
    }
    
    // Create thumbnail
    $thumbnail = imagecreatetruecolor($width, $height);
    
    // Preserve transparency
    if ($mimeType === 'image/png' || $mimeType === 'image/gif') {
        imagealphablending($thumbnail, false);
        imagesavealpha($thumbnail, true);
        $transparent = imagecolorallocatealpha($thumbnail, 255, 255, 255, 127);
        imagefilledrectangle($thumbnail, 0, 0, $width, $height, $transparent);
    }
    
    // Crop and resize
    imagecopyresampled($thumbnail, $sourceImage, 0, 0, $cropX, $cropY, $width, $height, $cropWidth, $cropHeight);
    
    // Save thumbnail
    $success = false;
    switch ($mimeType) {
        case 'image/jpeg':
            $success = imagejpeg($thumbnail, $thumbnailPath, 85);
            break;
        case 'image/png':
            $success = imagepng($thumbnail, $thumbnailPath, 9);
            break;
        case 'image/gif':
            $success = imagegif($thumbnail, $thumbnailPath);
            break;
        case 'image/webp':
            $success = imagewebp($thumbnail, $thumbnailPath, 85);
            break;
    }
    
    imagedestroy($sourceImage);
    imagedestroy($thumbnail);
    
    return $success ? $thumbnailPath : false;
}

/**
 * Generate video thumbnail
 * Note: Requires FFmpeg or similar tool
 * 
 * @param string $videoPath Video file path
 * @param string $thumbnailPath Thumbnail output path
 * @param int $timeOffset Time offset in seconds (default: 1 second)
 * @return string|false Thumbnail path or false on failure
 */
function generateVideoThumbnail($videoPath, $thumbnailPath, $timeOffset = 1) {
    if (!file_exists($videoPath)) {
        return false;
    }
    
    // Check if FFmpeg is available
    $ffmpegPath = 'ffmpeg'; // Default, can be configured
    $ffmpegCheck = shell_exec("which {$ffmpegPath} 2>&1");
    
    if (empty($ffmpegCheck)) {
        // FFmpeg not available, return false
        error_log("FFmpeg not found. Video thumbnail generation requires FFmpeg.");
        return false;
    }
    
    // Generate thumbnail using FFmpeg
    $command = escapeshellcmd($ffmpegPath) . " -i " . escapeshellarg($videoPath) . 
               " -ss " . intval($timeOffset) . 
               " -vframes 1 -q:v 2 " . escapeshellarg($thumbnailPath) . " 2>&1";
    
    exec($command, $output, $returnCode);
    
    if ($returnCode === 0 && file_exists($thumbnailPath)) {
        return $thumbnailPath;
    }
    
    return false;
}

/**
 * Get file size in human readable format
 */
function formatFileSize($bytes) {
    $units = ['B', 'KB', 'MB', 'GB'];
    $bytes = max($bytes, 0);
    $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
    $pow = min($pow, count($units) - 1);
    $bytes /= pow(1024, $pow);
    return round($bytes, 2) . ' ' . $units[$pow];
}

// No closing PHP tag to prevent whitespace output
