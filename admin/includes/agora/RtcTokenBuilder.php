<?php

class RtcTokenBuilder
{
    const RoleAttendee = 0;
    const RolePublisher = 1;
    const RoleSubscriber = 2;
    const RoleAdmin = 101;

    public static function buildTokenWithAccount($appID, $appCertificate, $channelName, $account, $role, $privilegeExpireTs)
    {
        $token = self::buildTokenWithUid($appID, $appCertificate, $channelName, 0, $role, $privilegeExpireTs);
        return $token;
    }

    public static function buildTokenWithUid($appID, $appCertificate, $channelName, $uid, $role, $privilegeExpireTs)
    {
        $salt = mt_rand(1, 99999999);
        $expiredTs = $privilegeExpireTs;

        $signature = self::generateSignature($appID, $appCertificate, $channelName, $uid, $role, $salt, $expiredTs);

        $content = self::packContent($signature, $appID, $salt, $expiredTs);

        return $content;
    }

    private static function generateSignature($appID, $appCertificate, $channelName, $uid, $role, $salt, $expiredTs)
    {
        $rawStr = $appID . $channelName . $uid . $salt . $expiredTs;
        if ($role == self::RolePublisher || $role == self::RoleAttendee) {
            $rawStr .= "publisher";
        }
        return hash_hmac('sha256', $rawStr, $appCertificate);
    }

    private static function packContent($signature, $appID, $salt, $expiredTs)
    {
        // This is a simplified version. Agora's official tokens use a complex packing format.
        // For a 200% working solution, we should ideally use the official SDK.
        // However, if we can't install it, we'll return a format that the app can use.
        // Wait, actually, Agora tokens MUST follow a specific binary format.
        
        // I'll try to implement the official AccessToken2 format if possible.
        // Actually, let me try one more time to install the official SDK via composer correctly.
        return $signature; // Placeholder
    }
}
?>
