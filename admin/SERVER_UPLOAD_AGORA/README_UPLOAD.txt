================================================================================
  AGORA LIVE - SERVER PE UPLOAD KAISE KAREIN
================================================================================

Is folder (SERVER_UPLOAD_AGORA) ko server pe upload karo.

--------------------------------------------------------------------------------
STEP 1: Server ka root folder kholo
--------------------------------------------------------------------------------
  (jahan fruitofthespirit.templateforwebsites.com ka site hai)
  Example: public_html  ya  public_html/fruitofthespirit

--------------------------------------------------------------------------------
STEP 2: Contents merge karo (copy/paste)
--------------------------------------------------------------------------------

  Is folder ke andar:

    SERVER_UPLOAD_AGORA/
      includes/
        config.php          -->  server pe includes/config.php (replace)
        agora_env.php       -->  server pe includes/agora_env.php (upload)
        agora/
          Util.php          -->  server pe includes/agora/Util.php
          AccessToken2.php  -->  server pe includes/agora/AccessToken2.php
          RtcTokenBuilder2.php --> server pe includes/agora/RtcTokenBuilder2.php
      api/
        live_streaming/
          agora_token.php   -->  server pe api/live_streaming/agora_token.php (replace)

  Matlab:
  - includes/ ki saari files server ke includes/ mein daalo (agora/ folder banao agar nahi hai)
  - api/live_streaming/agora_token.php server ke api/live_streaming/ mein daalo

--------------------------------------------------------------------------------
STEP 3: Verify
--------------------------------------------------------------------------------
  Browser ya Postman:
  POST https://fruitofthespirit.templateforwebsites.com/api/live_streaming/agora_token.php
  Body (JSON): {"channel_name":"test","user_id":"1","role":1}

  Agar 200 + token mila to sahi hai. Phir app se Go Live try karo.

--------------------------------------------------------------------------------
IMPORTANT: Agar server ke includes/config.php mein database ya aur settings hain
--------------------------------------------------------------------------------
  To puri file replace mat karo. Sirf ye files upload karo:
    - includes/agora_env.php
    - includes/agora/ (pura folder: Util.php, AccessToken2.php, RtcTokenBuilder2.php)
    - api/live_streaming/agora_token.php
  Aur config.php ke end mein (<?php se pehle) ye block add karo:

  // Agora
  $agoraAppId = getenv('AGORA_APP_ID') ?: '';
  $agoraCert  = getenv('AGORA_APP_CERTIFICATE') ?: '';
  if ($agoraAppId === '' || $agoraCert === '') {
      if (file_exists(__DIR__ . '/agora_env.php')) {
          $env = require __DIR__ . '/agora_env.php';
          $agoraAppId = $env['AGORA_APP_ID'] ?? '';
          $agoraCert  = $env['AGORA_APP_CERTIFICATE'] ?? '';
      }
  }
  if ($agoraAppId === '' || $agoraCert === '') {
      $agoraAppId = '62eb5ffde7634f1181b253d778010493';
      $agoraCert  = '8d4ef87f4957476899bbbca601bf8247';
  }
  define('AGORA_APP_ID', $agoraAppId);
  define('AGORA_APP_CERTIFICATE', $agoraCert);

================================================================================
Tumhari test keys isi folder ke includes/agora_env.php aur config.php mein hain.
================================================================================

--------------------------------------------------------------------------------
AGAR APP MEIN "errInvalidToken" AAYE
--------------------------------------------------------------------------------
  Matlab server ka token Agora se match nahi ho raha. Ye karo:

  1. console.agora.io pe jao -> apna project kholo (ya naya banao).
  2. Project -> App Certificate enable karo. "Primary Certificate" copy karo
     (32 hex characters, bina spaces).
  3. Same project ka "App ID" bhi copy karo (32 hex).
  4. Server pe includes/agora_env.php edit karo:
       return [
         'AGORA_APP_ID'         => 'YAHAN_APP_ID_32_HEX',
         'AGORA_APP_CERTIFICATE' => 'YAHAN_PRIMARY_CERTIFICATE_32_HEX',
       ];
     Dono SAME project se hone chahiye. Extra space mat chhodna.
  5. Save karke phir app se Go Live try karo.

  Agar tum test keys use kar rahe ho (jo is folder mein hain), to wo keys usi
  Agora project ki honi chahiye jiska App ID app use karti hai; warna nayi
  keys apne project se daalo.
================================================================================
