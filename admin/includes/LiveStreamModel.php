<?php

require_once 'db.php'; // Include the database connection

class LiveStreamModel {
    private $conn;

    public function __construct($db_connection) {
        $this->conn = $db_connection;
    }

    /**
     * Inserts a new live stream record into the database.
     *
     * @param string $stream_id The unique ID of the stream from Stream API.
     * @param string $user_id The ID of the user who created the stream.
     * @param string $title The title of the live stream.
     * @param string $description A description of the live stream.
     * @param string $status The current status of the stream (e.g., 'pending', 'live', 'ended').
     * @param string $stream_url The URL for viewing the stream.
     * @param string $thumbnail_url The URL for the stream's thumbnail.
     * @return array An associative array with 'success' (boolean) and 'message' (string) or 'error' (string).
     */
    public function createLiveStream($stream_id, $user_id, $title, $description, $status, $stream_url, $thumbnail_url) {
        $sql = "INSERT INTO live_streams (stream_id, user_id, title, description, status, stream_url, thumbnail_url) VALUES (?, ?, ?, ?, ?, ?, ?)";
        $stmt = $this->conn->prepare($sql);

        if ($stmt === false) {
            return ['success' => false, 'error' => 'Failed to prepare statement: ' . $this->conn->error];
        }

        $stmt->bind_param("sssssss", $stream_id, $user_id, $title, $description, $status, $stream_url, $thumbnail_url);

        if ($stmt->execute()) {
            return ['success' => true, 'message' => 'Live stream created successfully.'];
        } else {
            return ['success' => false, 'error' => 'Failed to execute statement: ' . $stmt->error];
        }
    }

    /**
     * Retrieves a live stream record by its ID.
     *
     * @param string $stream_id The unique ID of the stream.
     * @return array|null An associative array of the stream data, or null if not found.
     */
    public function getLiveStreamById($stream_id) {
        $sql = "SELECT * FROM live_streams WHERE stream_id = ?";
        $stmt = $this->conn->prepare($sql);

        if ($stmt === false) {
            error_log("Failed to prepare statement: " . $this->conn->error);
            return null;
        }

        $stmt->bind_param("s", $stream_id);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows > 0) {
            return $result->fetch_assoc();
        } else {
            return null;
        }
    }

    /**
     * Updates the status of a live stream.
     *
     * @param string $stream_id The unique ID of the stream.
     * @param string $new_status The new status to set.
     * @return array An associative array with 'success' (boolean) and 'message' (string) or 'error' (string).
     */
    public function updateLiveStreamStatus($stream_id, $new_status) {
        $sql = "UPDATE live_streams SET status = ? WHERE stream_id = ?";
        $stmt = $this->conn->prepare($sql);

        if ($stmt === false) {
            return ['success' => false, 'error' => 'Failed to prepare statement: ' . $this->conn->error];
        }

        $stmt->bind_param("ss", $new_status, $stream_id);

        if ($stmt->execute()) {
            return ['success' => true, 'message' => 'Live stream status updated successfully.'];
        } else {
            return ['success' => false, 'error' => 'Failed to execute statement: ' . $stmt->error];
        }
    }

    /**
     * Mark stream as ended (status = 'ended', end_time = NOW).
     * Use when the host ends the live; stream will no longer appear in "live" listing.
     *
     * @param string $stream_id The unique ID of the stream.
     * @return array An associative array with 'success' (boolean) and 'message' (string) or 'error' (string).
     */
    public function endLiveStream($stream_id) {
        $sql = "UPDATE live_streams SET status = 'ended', end_time = NOW() WHERE stream_id = ?";
        $stmt = $this->conn->prepare($sql);

        if ($stmt === false) {
            return ['success' => false, 'error' => 'Failed to prepare statement: ' . $this->conn->error];
        }

        $stmt->bind_param("s", $stream_id);

        if ($stmt->execute()) {
            return ['success' => true, 'message' => 'Live stream ended successfully.'];
        } else {
            return ['success' => false, 'error' => 'Failed to execute statement: ' . $stmt->error];
        }
    }

    /**
     * Gets all currently live streams (status = 'live' only). Ended streams are excluded so only LIVE videos show in the UI.
     *
     * @return array List of associative arrays (stream records).
     */
    public function getAllActiveLiveStreams() {
        // Use updated_at for sorting since that's when status was last changed
        $sql = "SELECT stream_id, user_id, title, description, status, thumbnail_url, viewer_count, created_at FROM live_streams WHERE status = 'live' ORDER BY updated_at DESC LIMIT 100";
        $result = $this->conn->query($sql);
        if ($result === false) {
            error_log("getAllActiveLiveStreams query failed: " . $this->conn->error);
            return [];
        }
        $rows = [];
        while ($row = $result->fetch_assoc()) {
            $rows[] = $row;
        }
        return $rows;
    }

    /**
     * Increment viewer count when a viewer joins a stream
     *
     * @param string $stream_id The stream ID
     * @return array Result with success status
     */
    public function incrementViewerCount($stream_id) {
        $sql = "UPDATE live_streams SET viewer_count = viewer_count + 1 WHERE stream_id = ?";
        $stmt = $this->conn->prepare($sql);
        if ($stmt === false) {
            return ['success' => false, 'error' => 'Failed to prepare statement: ' . $this->conn->error];
        }
        $stmt->bind_param("s", $stream_id);
        if ($stmt->execute()) {
            return ['success' => true, 'message' => 'Viewer count incremented'];
        }
        return ['success' => false, 'error' => 'Failed to execute statement: ' . $stmt->error];
    }

    /**
     * Decrement viewer count when a viewer leaves a stream
     *
     * @param string $stream_id The stream ID
     * @return array Result with success status
     */
    public function decrementViewerCount($stream_id) {
        $sql = "UPDATE live_streams SET viewer_count = GREATEST(0, viewer_count - 1) WHERE stream_id = ?";
        $stmt = $this->conn->prepare($sql);
        if ($stmt === false) {
            return ['success' => false, 'error' => 'Failed to prepare statement: ' . $this->conn->error];
        }
        $stmt->bind_param("s", $stream_id);
        if ($stmt->execute()) {
            return ['success' => true, 'message' => 'Viewer count decremented'];
        }
        return ['success' => false, 'error' => 'Failed to execute statement: ' . $stmt->error];
    }

    /**
     * Insert Agora live stream (no stream_url – table may not have that column).
     * Uses only: stream_id, user_id, title, description, status, thumbnail_url.
     */
    public function createLiveStreamAgora($stream_id, $user_id, $title, $description, $status, $thumbnail_url = '') {
        $sql = "INSERT INTO live_streams (stream_id, user_id, title, description, status, thumbnail_url) VALUES (?, ?, ?, ?, ?, ?)";
        $stmt = $this->conn->prepare($sql);
        if ($stmt === false) {
            return ['success' => false, 'error' => 'Failed to prepare statement: ' . $this->conn->error];
        }
        $stmt->bind_param("ssssss", $stream_id, $user_id, $title, $description, $status, $thumbnail_url);
        if ($stmt->execute()) {
            return ['success' => true, 'message' => 'Live stream created successfully.'];
        }
        return ['success' => false, 'error' => 'Failed to execute statement: ' . $stmt->error];
    }

    /**
     * Register/start an Agora live stream (insert or update to live). Used when broadcaster goes live.
     * Works with existing table that has: stream_id, user_id, title, description, status, thumbnail_url (no stream_url).
     *
     * @param string $stream_id Agora channel name (e.g. live_uid_timestamp).
     * @param string $user_id Broadcaster user ID.
     * @param string $title Stream title.
     * @param string $description Optional description.
     * @return array ['success' => bool, 'message' => string|'error' => string]
     */
    public function startAgoraLive($stream_id, $user_id, $title, $description = '') {
        $existing = $this->getLiveStreamById($stream_id);
        if ($existing) {
            return $this->updateLiveStreamStatus($stream_id, 'live');
        }
        return $this->createLiveStreamAgora($stream_id, $user_id, $title, $description ?: 'Live stream', 'live', '');
    }

    /**
     * Deletes a live stream record by its ID.
     *
     * @param string $stream_id The unique ID of the stream.
     * @return array An associative array with 'success' (boolean) and 'message' (string) or 'error' (string).
     */
    public function deleteLiveStream($stream_id) {
        $sql = "DELETE FROM live_streams WHERE stream_id = ?";
        $stmt = $this->conn->prepare($sql);

        if ($stmt === false) {
            return ['success' => false, 'error' => 'Failed to prepare statement: ' . $this->conn->error];
        }

        $stmt->bind_param("s", $stream_id);

        if ($stmt->execute()) {
            return ['success' => true, 'message' => 'Live stream deleted successfully.'];
        } else {
            return ['success' => false, 'error' => 'Failed to execute statement: ' . $stmt->error];
        }
    }
}
