<?php
session_start();
include 'redirect-if-logged-in.php'; 
require_once 'includes/db.php';



$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username_or_email = trim($_POST['username_or_email']);
    $password = $_POST['password'];
    
    if (!empty($username_or_email) && !empty($password)) {
        // Check if input is email or username
        if (filter_var($username_or_email, FILTER_VALIDATE_EMAIL)) {
            // It's an email
            $sql = "SELECT * FROM admin_users WHERE email = ? AND status = 'Active'";
        } else {
            // It's a username
            $sql = "SELECT * FROM admin_users WHERE name = ? AND status = 'Active'";
        }
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("s", $username_or_email);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows === 1) {
            $admin = $result->fetch_assoc();
            
            // Verify password (using MD5 as per your existing system)
            if (md5($password) === $admin['password_hash']) {
                // Update last login
                $update_sql = "UPDATE admin_users SET last_login = NOW() WHERE id = ?";
                $update_stmt = $conn->prepare($update_sql);
                $update_stmt->bind_param("i", $admin['id']);
                $update_stmt->execute();
                
                // Set session variables
                $_SESSION['admin_logged_in'] = true;
                $_SESSION['admin_id'] = $admin['id'];
                $_SESSION['admin_name'] = $admin['name'];
                $_SESSION['admin_email'] = $admin['email'];
                
                header("Location: index.php");
                exit;
            } else {
                $error = "Invalid username/email or password";
            }
        } else {
            $error = "Invalid username/email or password";
        }
    } else {
        $error = "Please fill in all fields";
    }
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Login - Fruit of the Spirit</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <style>
        :root {
            --primary: #e74c3c;      /* Light Red */
            --secondary: #f39c12;    /* Golden */
            --success: #27ae60;
            --info: #3498db;
            --warning: #f1c40f;
            --danger: #e74c3c;
            --light: #fdf6f6;        /* Very light red background */
            --dark: #2c3e50;
        }
        
        body {
            background: linear-gradient(135deg, #fdf6f6 0%, #fef9e7 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
        }
        
        .login-card {
            background: white;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(231, 76, 60, 0.1);
            overflow: hidden;
            border: 1px solid #f8d7da;
        }
        
        .login-header {
            background: linear-gradient(135deg, var(--primary) 0%, var(--secondary) 100%);
            color: white;
            padding: 2.5rem 2rem;
            text-align: center;
            position: relative;
            overflow: hidden;
        }
        
        .login-header::before {
            content: '';
            position: absolute;
            top: -50%;
            left: -50%;
            width: 200%;
            height: 200%;
            background: radial-gradient(circle, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0) 70%);
            transform: rotate(30deg);
        }
        
        .login-body {
            padding: 2.5rem;
            background: var(--light);
        }
        
        .form-control {
            border-radius: 10px;
            border: 2px solid #f8d7da;
            padding: 14px 16px;
            font-size: 15px;
            transition: all 0.3s ease;
            background: white;
        }
        
        .form-control:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 0.2rem rgba(231, 76, 60, 0.15);
        }
        
        .btn-primary {
            background: linear-gradient(135deg, var(--primary) 0%, var(--secondary) 100%);
            border: none;
            padding: 14px;
            border-radius: 10px;
            font-weight: 600;
            font-size: 16px;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(231, 76, 60, 0.3);
        }
        
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(231, 76, 60, 0.4);
        }
        
        .logo {
            font-size: 2.2rem;
            font-weight: 700;
            margin-bottom: 0.5rem;
            position: relative;
            z-index: 1;
        }
        
        .subtitle {
            opacity: 0.9;
            font-size: 0.95rem;
            position: relative;
            z-index: 1;
        }
        
        .auth-links {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-top: 1.5rem;
            padding-top: 1.5rem;
            border-top: 1px solid #f8d7da;
        }
        
        .auth-links a {
            color: var(--primary);
            text-decoration: none;
            font-weight: 500;
            transition: color 0.3s ease;
            display: flex;
            align-items: center;
            gap: 5px;
        }
        
        .auth-links a:hover {
            color: var(--secondary);
        }
        
        .alert-danger {
            background: rgba(231, 76, 60, 0.1);
            border: 1px solid rgba(231, 76, 60, 0.2);
            color: var(--danger);
            border-radius: 10px;
        }
        
        .form-label {
            font-weight: 600;
            color: var(--dark);
            margin-bottom: 8px;
        }
        
        .copyright {
            color: #7f8c8d;
            font-size: 0.85rem;
        }

        .password-wrap {
            position: relative;
        }
        .password-wrap .form-control {
            padding-right: 3rem;
        }
        .password-toggle {
            position: absolute;
            right: 12px;
            top: 50%;
            transform: translateY(-50%);
            background: none;
            border: none;
            color: #7f8c8d;
            cursor: pointer;
            padding: 6px;
            line-height: 1;
        }
        .password-toggle:hover, .password-toggle:focus-visible {
            color: var(--primary);
            outline: none;
        }
        
        /* Enhanced UI for username/email field */
        .input-group-text {
            background: white;
            border: 2px solid #f8d7da;
            border-right: none;
            border-radius: 10px 0 0 10px;
            color: var(--primary);
        }
        
        .input-group .form-control {
            border-radius: 0 10px 10px 0;
        }
        
        .info-badge {
            font-size: 0.8rem;
            color: #7f8c8d;
            margin-top: 5px;
            display: inline-flex;
            align-items: center;
            gap: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="row justify-content-center">
            <div class="col-md-5">
                <div class="login-card">
                    <div class="login-header">
                        <div class="logo">
                            <i class="bi bi-heart-fill me-2"></i>
                            Fruit of the Spirit
                        </div>
                        <div class="subtitle">Admin Panel Login</div>
                    </div>
                    <div class="login-body">
                        <?php if ($error): ?>
                            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                                <i class="bi bi-exclamation-triangle-fill me-2"></i>
                                <?php echo htmlspecialchars($error); ?>
                                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                            </div>
                        <?php endif; ?>
                        
                        <form method="POST" action="">
                            <div class="mb-4">
                                <label for="username_or_email" class="form-label">
                                    <i class="bi bi-person-badge me-2"></i>Username or Email
                                </label>
                                <div class="input-group">
                                    <span class="input-group-text">
                                        <i class="bi bi-envelope-at"></i>
                                    </span>
                                    <input type="text" class="form-control" id="username_or_email" name="username_or_email" required 
                                           placeholder="Enter username or email address" 
                                           value="<?php echo isset($_POST['username_or_email']) ? htmlspecialchars($_POST['username_or_email']) : ''; ?>">
                                </div>
                              
                            </div>
                            
                            <div class="mb-4">
                                <label for="password" class="form-label">
                                    <i class="bi bi-lock me-2"></i>Password
                                </label>
                                <div class="password-wrap">
                                    <input type="password" class="form-control" id="password" name="password" required 
                                           placeholder="Enter your password" autocomplete="current-password">
                                    <button type="button" class="password-toggle" id="togglePassword" aria-label="Show password">
                                        <i class="bi bi-eye"></i>
                                    </button>
                                </div>
                            </div>
                            
                            <div class="d-grid mb-3">
                                <button type="submit" class="btn btn-primary btn-lg">
                                    <i class="bi bi-box-arrow-in-right me-2"></i>Sign In
                                </button>
                            </div>
                        </form>
                     
                    </div>
                </div>
                
                <div class="text-center mt-4 copyright">
                    <small>&copy; 2026 Fruit of the Spirit. All rights reserved.</small>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
    (function () {
        var input = document.getElementById('password');
        var btn = document.getElementById('togglePassword');
        if (!input || !btn) return;
        btn.addEventListener('click', function () {
            var show = input.type === 'password';
            input.type = show ? 'text' : 'password';
            btn.setAttribute('aria-label', show ? 'Hide password' : 'Show password');
            btn.innerHTML = show ? '<i class="bi bi-eye-slash"></i>' : '<i class="bi bi-eye"></i>';
        });
    })();
    </script>
</body>
</html>