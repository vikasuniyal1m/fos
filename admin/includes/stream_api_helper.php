<?php

require_once 'config.php'; // For STREAM_API_BASE_URL

class StreamApiHelper {
    private $apiKey;
    private $apiSecret;
    private $apiBaseUrl;

    public function __construct($apiKey, $apiSecret) {
        $this->apiKey = $apiKey;
        $this->apiSecret = $apiSecret;
        $this->apiBaseUrl = STREAM_API_BASE_URL;
    }

    private function makeApiRequest($endpoint, $method = 'GET', $data = []) {
        $url = $this->apiBaseUrl . $endpoint;
        $ch = curl_init($url);

        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Authorization: Bearer ' . $this->apiSecret,
            'X-Stream-Client-Key: ' . $this->apiKey
        ]);

        if ($method === 'POST' || $method === 'PUT') {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);

        curl_close($ch);

        if ($curlError) {
            // Log error or handle it appropriately
            return ['success' => false, 'error' => 'cURL Error: ' . $curlError];
        }

        $responseData = json_decode($response, true);

        if ($httpCode >= 200 && $httpCode < 300) {
            return ['success' => true, 'data' => $responseData];
        } else {
            return ['success' => false, 'error' => 'Stream API Error', 'details' => $responseData, 'http_code' => $httpCode];
        }
    }

    public function createStream($streamId, $userId, $options = []) {
        $endpoint = '/api/v1.0/video/streams'; // Hypothetical endpoint
        $data = array_merge([
            'id' => $streamId,
            'user_id' => $userId,
        ], $options);
        return $this->makeApiRequest($endpoint, 'POST', $data);
    }

    public function getStream($streamId) {
        $endpoint = '/api/v1.0/video/streams/' . $streamId; // Hypothetical endpoint
        return $this->makeApiRequest($endpoint, 'GET');
    }

    public function stopStream($streamId) {
        $endpoint = '/api/v1.0/video/streams/' . $streamId . '/stop'; // Hypothetical endpoint
        return $this->makeApiRequest($endpoint, 'POST');
    }

    // Add other stream management functions as needed (e.g., updateStream, deleteStream)

    public function generateToken($userId) {
        $endpoint = '/api/v1.0/video/token'; // Adjust endpoint as per Stream's documentation
        $data = ['user_id' => $userId];
        return $this->makeApiRequest($endpoint, 'POST', $data);
    }
}

?>