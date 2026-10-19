<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Get video ID from URL
$video_id = intval($_GET['id'] ?? 0);

// Fetch video details
$video = null;
if($video_id) {
    $stmt = $conn->prepare("SELECT lv.*, u.name AS user_name FROM live_videos lv 
                           LEFT JOIN users u ON lv.user_id = u.id 
                           WHERE lv.id = ?");
    $stmt->bind_param("i", $video_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $video = $result->fetch_assoc();
}

// If video not found, show error
if(!$video) {
    echo '<div class="dashboard-main-body">
        <div class="alert alert-danger m-24">
            <h4>Video Not Found</h4>
            <p>The requested video does not exist.</p>
            <a href="live-videos.php" class="btn btn-primary mt-16">Back to Live Videos</a>
        </div>
    </div>';
    include './partials/layouts/layoutBottom.php';
    exit;
}

// Use dummy video URLs for testing
$dummyVideos = [
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4'
];

// Select a random dummy video for testing
$randomVideo = $dummyVideos[array_rand($dummyVideos)];
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Watch Live Video</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="mdi:home-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">
                <a href="live-videos.php" class="hover-text-primary">Live Videos</a>
            </li>
            <li>-</li>
            <li class="fw-medium">Watch Live</li>
        </ul>
    </div>

    <div class="row">
        <div class="col-lg-8">
            <!-- Video Player Section -->
            <div class="card radius-12 mb-24">
                <div class="card-header border-bottom bg-base py-16 px-24">
                    <h6 class="fw-semibold mb-0"><?php echo htmlspecialchars($video['title']); ?></h6>
                </div>
                <div class="card-body p-24">
                    <!-- Video Player -->
                    <div class="video-container mb-16 radius-12 bg-dark position-relative" style="height: 400px;">
                        <video id="liveVideoPlayer" controls class="w-100 h-100 radius-12" 
                               poster="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg">
                            <source src="<?php echo $randomVideo; ?>" type="video/mp4">
                            Your browser does not support the video tag.
                        </video>
                        <?php if($video['status'] == 'Live'): ?>
                        <div class="live-badge position-absolute top-16 right-16">
                            <span class="badge bg-danger px-16 py-4 fw-medium">
                                <iconify-icon icon="mdi:broadcast" class="icon me-1"></iconify-icon>
                                LIVE
                            </span>
                        </div>
                        <?php endif; ?>
                    </div>

                    <!-- Video Controls -->
                    <div class="d-flex justify-content-between align-items-center">
                        <div class="d-flex gap-12">
                            <button id="playBtn" class="btn btn-primary btn-sm">
                                <iconify-icon icon="mdi:play" class="icon me-1"></iconify-icon>
                                Play
                            </button>
                            <button id="pauseBtn" class="btn btn-secondary btn-sm">
                                <iconify-icon icon="mdi:pause" class="icon me-1"></iconify-icon>
                                Pause
                            </button>
                            <button id="fullscreenBtn" class="btn btn-outline-primary btn-sm">
                                <iconify-icon icon="mdi:fullscreen" class="icon me-1"></iconify-icon>
                                Fullscreen
                            </button>
                            <button id="muteBtn" class="btn btn-outline-secondary btn-sm">
                                <iconify-icon icon="mdi:volume-high" class="icon me-1"></iconify-icon>
                                Mute
                            </button>
                        </div>
                        <div class="text-muted">
                            <span id="viewerCount"><?php echo $video['viewer_count']; ?></span> viewers
                        </div>
                    </div>
                </div>
            </div>

            <!-- Video Description -->
            <div class="card radius-12">
                <div class="card-header border-bottom bg-base py-16 px-24">
                    <h6 class="fw-semibold mb-0">About This Stream</h6>
                </div>
                <div class="card-body p-24">
                    <p class="text-muted mb-16"><?php echo htmlspecialchars($video['description'] ?? 'No description available.'); ?></p>
                    
                    <div class="row">
                        <div class="col-md-6">
                            <div class="d-flex align-items-center gap-8 mb-12">
                                <iconify-icon icon="mdi:calendar" class="icon text-primary"></iconify-icon>
                                <span class="text-muted">Started:</span>
                                <span class="fw-medium ms-2">
                                    <?php echo $video['started_at'] ? date('M j, Y H:i', strtotime($video['started_at'])) : 'Not started'; ?>
                                </span>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="d-flex align-items-center gap-8 mb-12">
                                <iconify-icon icon="mdi:tag" class="icon text-primary"></iconify-icon>
                                <span class="text-muted">Fruit Tag:</span>
                                <span class="badge bg-primary ms-2"><?php echo htmlspecialchars($video['fruit_tag']); ?></span>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="d-flex align-items-center gap-8 mb-12">
                                <iconify-icon icon="mdi:account" class="icon text-primary"></iconify-icon>
                                <span class="text-muted">Status:</span>
                                <span class="badge <?php 
                                    echo $video['status'] == 'Live' ? 'bg-success' : 
                                         ($video['status'] == 'Pending' ? 'bg-warning' : 'bg-danger'); 
                                ?> ms-2">
                                    <?php echo $video['status']; ?>
                                </span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="col-lg-4">
            <!-- Streamer Info -->
            <div class="card radius-12 mb-24">
                <div class="card-header border-bottom bg-base py-16 px-24">
                    <h6 class="fw-semibold mb-0">Streamer Information</h6>
                </div>
                <div class="card-body p-24">
                    <div class="d-flex align-items-center gap-12 mb-16">
                        <div class="avatar avatar-lg bg-primary text-white rounded-circle d-flex align-items-center justify-content-center fw-semibold">
                            <?php echo strtoupper(substr($video['user_name'], 0, 1)); ?>
                        </div>
                        <div>
                            <h6 class="fw-semibold mb-2"><?php echo htmlspecialchars($video['user_name']); ?></h6>
                            <span class="text-muted">Content Creator</span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Quick Actions -->
            <div class="card radius-12">
                <div class="card-body p-24">
                    <h6 class="fw-semibold mb-16">Quick Actions</h6>
                    <div class="d-grid gap-12">
                        <a href="live-videos.php" class="btn btn-outline-primary">
                            <iconify-icon icon="mdi:arrow-left" class="icon me-2"></iconify-icon>
                            Back to Videos
                        </a>
                        <button class="btn btn-outline-secondary" onclick="location.reload()">
                            <iconify-icon icon="mdi:refresh" class="icon me-2"></iconify-icon>
                            Refresh Page
                        </button>
                    </div>
                </div>
            </div>

            <!-- Video Info -->
            <div class="card radius-12 mt-24">
                <div class="card-header border-bottom bg-base py-16 px-24">
                    <h6 class="fw-semibold mb-0">Video Information</h6>
                </div>
                <div class="card-body p-24">
                    <div class="d-flex justify-content-between mb-12">
                        <span class="text-muted">Video ID:</span>
                        <span class="fw-medium">#<?php echo $video['id']; ?></span>
                    </div>
                    <div class="d-flex justify-content-between mb-12">
                        <span class="text-muted">Created:</span>
                        <span class="fw-medium"><?php echo date('M j, Y', strtotime($video['created_at'])); ?></span>
                    </div>
                    <div class="d-flex justify-content-between">
                        <span class="text-muted">Current Viewers:</span>
                        <span class="fw-medium text-success" id="currentViewers"><?php echo $video['viewer_count']; ?></span>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<style>
.video-container {
    background: #000;
    overflow: hidden;
    position: relative;
}

.live-badge {
    z-index: 10;
}

.avatar {
    width: 48px;
    height: 48px;
    font-size: 18px;
}

#liveVideoPlayer {
    object-fit: contain;
}

.video-controls {
    background: rgba(0,0,0,0.8);
    padding: 10px;
    border-radius: 0 0 12px 12px;
}
</style>

<script>
$(document).ready(function() {
    const videoPlayer = document.getElementById('liveVideoPlayer');
    const playBtn = document.getElementById('playBtn');
    const pauseBtn = document.getElementById('pauseBtn');
    const fullscreenBtn = document.getElementById('fullscreenBtn');
    const muteBtn = document.getElementById('muteBtn');
    const viewerCount = document.getElementById('viewerCount');
    const currentViewers = document.getElementById('currentViewers');

    // Auto-play video when page loads
    videoPlayer.play().catch(function(error) {
        console.log('Auto-play prevented, waiting for user interaction');
    });

    // Play button
    playBtn.addEventListener('click', function() {
        videoPlayer.play();
        playBtn.disabled = true;
        pauseBtn.disabled = false;
    });

    // Pause button
    pauseBtn.addEventListener('click', function() {
        videoPlayer.pause();
        playBtn.disabled = false;
        pauseBtn.disabled = true;
    });

    // Fullscreen button
    fullscreenBtn.addEventListener('click', function() {
        if (videoPlayer.requestFullscreen) {
            videoPlayer.requestFullscreen();
        } else if (videoPlayer.webkitRequestFullscreen) {
            videoPlayer.webkitRequestFullscreen();
        } else if (videoPlayer.msRequestFullscreen) {
            videoPlayer.msRequestFullscreen();
        }
    });

    // Mute button
    let isMuted = false;
    muteBtn.addEventListener('click', function() {
        isMuted = !isMuted;
        videoPlayer.muted = isMuted;
        muteBtn.innerHTML = isMuted ? 
            '<iconify-icon icon="mdi:volume-off" class="icon me-1"></iconify-icon>Unmute' :
            '<iconify-icon icon="mdi:volume-high" class="icon me-1"></iconify-icon>Mute';
        muteBtn.classList.toggle('btn-outline-danger', isMuted);
        muteBtn.classList.toggle('btn-outline-secondary', !isMuted);
    });

    // Video event listeners
    videoPlayer.addEventListener('play', function() {
        playBtn.disabled = true;
        pauseBtn.disabled = false;
    });

    videoPlayer.addEventListener('pause', function() {
        playBtn.disabled = false;
        pauseBtn.disabled = true;
    });

    // Update viewer count (simulated)
    function updateViewerCount() {
        let count = <?php echo $video['viewer_count']; ?>;
        // Simulate realistic viewer count changes
        const change = Math.floor(Math.random() * 5) - 2; // -2 to +2
        count = Math.max(count + change, 1); // Ensure at least 1 viewer
        
        viewerCount.textContent = count;
        currentViewers.textContent = count;
        
        // Update every 30 seconds
        setTimeout(updateViewerCount, 30000);
    }

    // Initialize viewer count updates
    updateViewerCount();

    // Keyboard shortcuts
    document.addEventListener('keydown', function(e) {
        switch(e.key) {
            case ' ':
            case 'k':
                e.preventDefault();
                if(videoPlayer.paused) {
                    videoPlayer.play();
                } else {
                    videoPlayer.pause();
                }
                break;
            case 'f':
                e.preventDefault();
                if (videoPlayer.requestFullscreen) {
                    videoPlayer.requestFullscreen();
                }
                break;
            case 'm':
                e.preventDefault();
                isMuted = !isMuted;
                videoPlayer.muted = isMuted;
                break;
        }
    });

    // Enable fullscreen for the entire video container
    function enterFullscreen(element) {
        if(element.requestFullscreen) {
            element.requestFullscreen();
        } else if(element.webkitRequestFullscreen) {
            element.webkitRequestFullscreen();
        } else if(element.msRequestFullscreen) {
            element.msRequestFullscreen();
        }
    }

    // Update fullscreen button to work with container
    fullscreenBtn.addEventListener('click', function() {
        enterFullscreen(videoPlayer.parentElement);
    });

    // Show video controls info
    console.log('Video Controls:');
    console.log('- Space/K: Play/Pause');
    console.log('- F: Fullscreen');
    console.log('- M: Mute/Unmute');
});
</script>

<?php include './partials/layouts/layoutBottom.php'; ?>