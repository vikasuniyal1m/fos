<?php
$host = "localhost"; // DB host
$dbname = "u337843438_fruitofspirit"; // DB name
$username = "u337843438_fruitofspirit"; // DB username
$password = "Dwis2826@";

// Create connection
$conn = new mysqli($host, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    // Store error for later checking
    $db_connection_error = $conn->connect_error;
} else {
    // Set charset to UTF-8
    $conn->set_charset("utf8mb4");
}
