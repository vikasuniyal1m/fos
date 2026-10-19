<?php
session_start();
include './includes/db.php';
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Signup - Blogger Request</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <style>
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        .card {
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            border: none;
        }
        .card-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border-radius: 20px 20px 0 0 !important;
            padding: 20px;
            text-align: center;
        }
        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border: none;
            padding: 12px;
            font-weight: bold;
        }
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.3);
        }
        .form-control:focus {
            border-color: #764ba2;
            box-shadow: 0 0 0 0.2rem rgba(118, 75, 162, 0.25);
        }
        .alert {
            border-radius: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="row justify-content-center">
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header">
                        <h3 class="mb-0">📝 Test Signup</h3>
                        <p class="mb-0">Create account & request to become Blogger</p>
                    </div>
                    <div class="card-body p-4">
                        <div id="message"></div>
                        
                        <form id="signupForm">
                            <div class="mb-3">
                                <label class="form-label">Full Name *</label>
                                <input type="text" class="form-control" id="name" required>
                            </div>
                            
                            <div class="mb-3">
                                <label class="form-label">Email *</label>
                                <input type="email" class="form-control" id="email" required>
                            </div>
                            
                            <div class="mb-3">
                                <label class="form-label">Phone (Optional)</label>
                                <input type="text" class="form-control" id="phone">
                            </div>
                            
                            <div class="mb-3">
                                <label class="form-label">Password *</label>
                                <input type="password" class="form-control" id="password" required>
                            </div>
                            
                            <div class="mb-3">
                                <label class="form-label">Confirm Password *</label>
                                <input type="password" class="form-control" id="confirm_password" required>
                            </div>
                            
                            <div class="mb-4">
                                <div class="form-check">
                                    <input class="form-check-input" type="checkbox" id="requestBlogger" checked>
                                    <label class="form-check-label" for="requestBlogger">
                                        🚀 Request to become a Blogger (Admin approval required)
                                    </label>
                                </div>
                            </div>
                            
                            <button type="submit" class="btn btn-primary w-100">
                                Sign Up & Request Blogger Role
                            </button>
                        </form>
                        
                        <hr class="my-4">
                        
                        <div class="text-center">
                            <p class="mb-0">Already have an account? <a href="test-login.php">Login here</a></p>
                        </div>
                    </div>
                </div>
                
                <div class="card mt-3">
                    <div class="card-body bg-light">
                        <h6 class="mb-2">📌 Testing Notes:</h6>
                        <small>
                            • New users will be created with role = <strong>User</strong> or <strong>PendingBlogger</strong><br>
                            • If you check "Request to become Blogger" → Role = <strong class="text-warning">PendingBlogger</strong><br>
                            • Admin can approve/reject from Users Grid page<br>
                            • Default password hash uses bcrypt
                        </small>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
    $(document).ready(function(){
        $("#signupForm").submit(function(e){
            e.preventDefault();
            
            let name = $("#name").val();
            let email = $("#email").val();
            let phone = $("#phone").val();
            let password = $("#password").val();
            let confirm_password = $("#confirm_password").val();
            let requestBlogger = $("#requestBlogger").is(":checked");
            
            // Validation
            if(!name || !email || !password) {
                showMessage("Please fill all required fields", "danger");
                return;
            }
            
            if(password !== confirm_password) {
                showMessage("Passwords do not match", "danger");
                return;
            }
            
            if(password.length < 6) {
                showMessage("Password must be at least 6 characters", "danger");
                return;
            }
            
            $.ajax({
                url: "process-signup.php",
                type: "POST",
                data: {
                    name: name,
                    email: email,
                    phone: phone,
                    password: password,
                    request_blogger: requestBlogger
                },
                dataType: "json",
                success: function(response) {
                    if(response.success) {
                        showMessage(response.message, "success");
                        $("#signupForm")[0].reset();
                        setTimeout(function(){
                            window.location.href = "test-login.php";
                        }, 2000);
                    } else {
                        showMessage(response.message, "danger");
                    }
                },
                error: function() {
                    showMessage("Something went wrong", "danger");
                }
            });
        });
        
        function showMessage(msg, type) {
            let alertClass = type === "success" ? "alert-success" : "alert-danger";
            $("#message").html('<div class="alert ' + alertClass + ' alert-dismissible fade show" role="alert">' + msg + '<button type="button" class="btn-close" data-bs-dismiss="alert"></button></div>');
            setTimeout(function(){
                $(".alert").fadeOut();
            }, 3000);
        }
    });
    </script>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>