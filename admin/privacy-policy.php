<?php
// Simple privacy policy content
$privacy_content = '
<div class="policy-content">
    <h2>Privacy Policy</h2>
    <p class="last-updated">Last Updated: ' . date('F j, Y') . '</p>
    
    <div class="section">
        <h3>1. Information We Collect</h3>
        <p>When you contact us through our support form, we collect:</p>
        <ul>
            <li>Your name</li>
            <li>Email address</li>
            <li>The message you send us</li>
        </ul>
    </div>
    
    <div class="section">
        <h3>2. How We Use Your Information</h3>
        <p>We use the information you provide to:</p>
        <ul>
            <li>Respond to your support requests</li>
            <li>Improve our services</li>
            <li>Communicate with you about your inquiry</li>
        </ul>
    </div>
    
    <div class="section">
        <h3>3. Information Protection</h3>
        <p>We take reasonable measures to protect your personal information from unauthorized access, alteration, or disclosure.</p>
    </div>
    
    <div class="section">
        <h3>4. Third-Party Sharing</h3>
        <p>We do not sell, trade, or rent your personal information to third parties. Your information is only used to respond to your inquiry.</p>
    </div>
    
    <div class="section">
        <h3>5. Your Rights</h3>
        <p>You have the right to:</p>
        <ul>
            <li>Request access to your personal information</li>
            <li>Request correction of your information</li>
            <li>Request deletion of your information</li>
            <li>Opt-out of communications</li>
        </ul>
    </div>
    
    <div class="section">
        <h3>6. Contact Us</h3>
        <p>If you have any questions about this Privacy Policy, please contact us at:</p>
        <div class="contact-info">
            <p><strong>Email:</strong> Clifton.Daye@Day2Daye.com</p>
        </div>
    </div>
    
    <div class="section">
        <h3>7. Changes to This Policy</h3>
        <p>We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy on this page.</p>
    </div>
</div>
';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f5f7fa;
            padding: 20px;
            min-height: 100vh;
        }
        
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 2px 20px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }
        
        .header {
            background: #2c3e50;
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 32px;
            margin-bottom: 10px;
        }
        
        .header p {
            opacity: 0.9;
            font-size: 16px;
        }
        
        .content {
            padding: 40px;
        }
        
        .policy-content h2 {
            color: #2c3e50;
            margin-bottom: 30px;
            padding-bottom: 15px;
            border-bottom: 2px solid #eee;
        }
        
        .last-updated {
            color: #666;
            font-style: italic;
            margin-bottom: 40px;
            padding: 10px;
            background: #f8f9fa;
            border-radius: 5px;
        }
        
        .section {
            margin-bottom: 40px;
        }
        
        .section h3 {
            color: #2c3e50;
            margin-bottom: 15px;
            font-size: 20px;
        }
        
        .section p {
            margin-bottom: 15px;
            color: #555;
        }
        
        .section ul {
            margin-left: 20px;
            margin-bottom: 15px;
            color: #555;
        }
        
        .section li {
            margin-bottom: 8px;
        }
        
        .contact-info {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 5px;
            margin-top: 15px;
        }
        
        .contact-info p {
            margin: 0;
        }
        
        .footer {
            margin-top: 50px;
            text-align: center;
            padding-top: 20px;
            border-top: 1px solid #eee;
            color: #666;
        }
        
        .footer a {
            color: #3498db;
            text-decoration: none;
        }
        
        .footer a:hover {
            text-decoration: underline;
        }
        
        .back-button {
            display: inline-block;
            margin-top: 20px;
            padding: 10px 20px;
            background: #3498db;
            color: #fff !important;
            text-decoration: none;
            border-radius: 5px;
            font-weight: 500;
            transition: background-color 0.3s;
        }
        
        .back-button:hover {
            background: #2980b9;
        }
        
        @media (max-width: 768px) {
            .container {
                border-radius: 0;
            }
            
            .content {
                padding: 20px;
            }
            
            .header {
                padding: 20px;
            }
            
            .header h1 {
                font-size: 24px;
            }
        }
        
        /* Print styles */
        @media print {
            body {
                background: white;
                padding: 0;
            }
            
            .container {
                box-shadow: none;
                border-radius: 0;
            }
            
            .footer {
                display: none;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Privacy Policy</h1>
            <p>How we collect, use, and protect your information</p>
        </div>
        
        <div class="content">
            <?php echo $privacy_content; ?>
            
            <div class="footer">
                <p>If you have any questions about our privacy practices, please contact us.</p>
                <a href="contact-support.php" class="back-button">Contact Support</a>
                <p style="margin-top: 20px;"><a href="index.php">← Back to Home</a></p>
                <p style="margin-top: 10px; font-size: 14px;">© <?php echo date('Y'); ?> All rights reserved.</p>
            </div>
        </div>
    </div>
    
    <script>
        // Print button functionality
        function addPrintButton() {
            const printBtn = document.createElement('button');
            printBtn.innerHTML = 'Print This Policy';
            printBtn.style.cssText = `
                position: fixed;
                bottom: 20px;
                right: 20px;
                background: #2c3e50;
                color: white;
                border: none;
                padding: 10px 20px;
                border-radius: 5px;
                cursor: pointer;
                font-size: 14px;
                z-index: 1000;
            `;
            printBtn.onclick = () => window.print();
            document.body.appendChild(printBtn);
        }
        
        document.addEventListener('DOMContentLoaded', addPrintButton);
        
        // Smooth scroll for anchor links
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', function (e) {
                e.preventDefault();
                const targetId = this.getAttribute('href');
                if (targetId !== '#') {
                    const targetElement = document.querySelector(targetId);
                    if (targetElement) {
                        targetElement.scrollIntoView({
                            behavior: 'smooth',
                            block: 'start'
                        });
                    }
                }
            });
        });
    </script>
</body>
</html>