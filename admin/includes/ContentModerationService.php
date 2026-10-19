<?php
/**
 * Content Moderation Service
 * Handles keyword filtering, content sanitization, and moderation actions
 */

class ContentModerationService {
    
    /**
     * Check content against moderation keywords
     * @param string $content - Content to check
     * @param mysqli $conn - Database connection
     * @return array ['action' => 'allow|warn|quarantine|block', 'sanitized_content' => string, 'matched_keywords' => array]
     */
    public static function checkContent($content, $conn) {
        // Get active keywords from database
        $keywords_query = "SELECT keyword, severity, action FROM moderation_keywords WHERE is_active = 1";
        $result = $conn->query($keywords_query);
        
        $matched_keywords = [];
        $highest_severity = 'allow';
        $highest_action = 'allow';
        
        $severity_order = ['allow' => 0, 'warn' => 1, 'quarantine' => 2, 'block' => 3];
        
        while ($row = $result->fetch_assoc()) {
            $keyword = $row['keyword'];
            $pattern = '/\b' . preg_quote($keyword, '/') . '\b/i';
            
            if (preg_match($pattern, $content)) {
                $matched_keywords[] = [
                    'keyword' => $keyword,
                    'severity' => $row['severity'],
                    'action' => $row['action']
                ];
                
                // Track highest severity action
                if ($severity_order[$row['action']] > $severity_order[$highest_action]) {
                    $highest_action = $row['action'];
                    $highest_severity = $row['severity'];
                }
            }
        }
        
        return [
            'action' => $highest_action,
            'severity' => $highest_severity,
            'matched_keywords' => $matched_keywords,
            'sanitized_content' => self::sanitizeContent($content, $matched_keywords)
        ];
    }
    
    /**
     * Sanitize content by replacing bad words with asterisks
     * @param string $content - Original content
     * @param array $matched_keywords - Keywords to sanitize
     * @return string - Sanitized content
     */
    public static function sanitizeContent($content, $matched_keywords) {
        foreach ($matched_keywords as $match) {
            if ($match['action'] === 'warn' || $match['action'] === 'quarantine') {
                $keyword = $match['keyword'];
                $replacement = str_repeat('*', strlen($keyword));
                $pattern = '/\b' . preg_quote($keyword, '/') . '\b/i';
                $content = preg_replace($pattern, $replacement, $content);
            }
        }
        return $content;
    }
    
    /**
     * Update moderation status in database
     * @param string $table - Table name
     * @param int $id - Content ID
     * @param string $status - Moderation status
     * @param string $notes - Moderation notes
     * @param mysqli $conn - Database connection
     */
    public static function updateModerationStatus($table, $id, $status, $notes, $conn) {
        $status_column = ($table === 'comments') ? 'status' : 'moderation_status';
        
        $sql = "UPDATE {$table} 
                SET {$status_column} = ?, 
                    moderation_notes = ?, 
                    moderated_at = NOW() 
                WHERE id = ?";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("ssi", $status, $notes, $id);
        $stmt->execute();
    }
    
    /**
     * Increment flag count
     * @param string $table - Table name
     * @param int $id - Content ID
     * @param mysqli $conn - Database connection
     */
    public static function incrementFlagCount($table, $id, $conn) {
        $sql = "UPDATE {$table} SET flag_count = flag_count + 1 WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $id);
        $stmt->execute();
    }
    
    /**
     * Notify admins about flagged content
     * @param string $content_type - Type of content
     * @param int $content_id - Content ID
     * @param string $reason - Reason for flagging
     */
    public static function notifyAdmins($content_type, $content_id, $reason) {
        // Log to error log
        error_log("MODERATION ALERT: {$content_type} ID {$content_id} - Reason: {$reason}");
        
        // TODO: Send email to admin (optional)
        // mail('admin@fruitofthespirit.com', 'Content Flagged', $message);
    }
}
?>
