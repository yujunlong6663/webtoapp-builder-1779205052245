#!/bin/bash
set -e

echo "=== Patching Android permissions ==="

MANIFEST_FILE="android/app/src/main/AndroidManifest.xml"

if [ ! -f "$MANIFEST_FILE" ]; then
    echo "ERROR: AndroidManifest.xml not found!"
    exit 1
fi

# 1. Add all required permissions to AndroidManifest.xml
for perm in "android.permission.ACCESS_FINE_LOCATION" "android.permission.ACCESS_COARSE_LOCATION" "android.permission.CAMERA" "android.permission.READ_MEDIA_IMAGES" "android.permission.READ_EXTERNAL_STORAGE" "android.permission.READ_CONTACTS" "android.permission.WRITE_CONTACTS" "android.permission.CALL_PHONE" "android.permission.READ_PHONE_STATE"; do
    if ! grep -q "$perm" "$MANIFEST_FILE"; then
        sed -i "/<uses-permission/a\\    <uses-permission android:name=\"$perm\" />" "$MANIFEST_FILE"
        echo "Added permission: $perm"
    fi
done

# 2. Add tel intent query for phone calls
if ! grep -q "android.intent.action.DIAL" "$MANIFEST_FILE"; then
    if grep -q "<queries>" "$MANIFEST_FILE"; then
        sed -i '/<queries>/a\\        <intent>\n            <action android:name="android.intent.action.DIAL" />\n            <data android:scheme="tel" />\n        </intent>' "$MANIFEST_FILE"
    else
        sed -i '/<application/i\\    <queries>\n        <intent>\n            <action android:name="android.intent.action.DIAL" />\n            <data android:scheme="tel" />\n        </intent>\n    </queries>' "$MANIFEST_FILE"
    fi
fi

# 3. Replace MainActivity with custom one that handles permissions
ACTIVITY_DIR="android/app/src/main/java/com/webtoapp/app"
mkdir -p "$ACTIVITY_DIR"
cat > "$ACTIVITY_DIR/MainActivity.java" << 'MAINACTIVITY_EOF'
package com.webtoapp.app;

import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {

    private static final String TAG = "WebToApp";
    private static final int PERMISSION_REQUEST_CODE = 100;
    private String[] requiredPermissions = new String[]{"android.permission.ACCESS_FINE_LOCATION", "android.permission.ACCESS_COARSE_LOCATION", "android.permission.CAMERA", "android.permission.READ_MEDIA_IMAGES", "android.permission.READ_EXTERNAL_STORAGE", "android.permission.READ_CONTACTS", "android.permission.WRITE_CONTACTS", "android.permission.CALL_PHONE", "android.permission.READ_PHONE_STATE"};

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestAllPermissions();
    }

    private void requestAllPermissions() {
        java.util.List<String> needed = new java.util.ArrayList<>();
        for (String perm : requiredPermissions) {
            if (ContextCompat.checkSelfPermission(this, perm) != PackageManager.PERMISSION_GRANTED) {
                needed.add(perm);
            }
        }
        if (!needed.isEmpty()) {
            ActivityCompat.requestPermissions(this, needed.toArray(new String[0]), PERMISSION_REQUEST_CODE);
            Log.d(TAG, "Requesting " + needed.size() + " permissions");
        } else {
            Log.d(TAG, "All permissions already granted");
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        Log.d(TAG, "Permission results received");
    }

    @Override
    public void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        // Handle tel: intent from WebView
        if (intent != null && intent.getData() != null && "tel".equals(intent.getData().getScheme())) {
            Intent dialIntent = new Intent(Intent.ACTION_DIAL, intent.getData());
            startActivity(dialIntent);
        }
    }
}

MAINACTIVITY_EOF
echo "Custom MainActivity.java created"

# 4. Copy custom icon if exists
if [ -f "../app-icon.png" ]; then
    echo "Custom icon detected, copying..."
    for dir in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
        mkdir -p "android/app/src/main/res/mipmap-$dir"
        cp ../app-icon.png "android/app/src/main/res/mipmap-$dir/ic_launcher.png"
    done
fi

echo "=== Permission patch completed! ==="
echo "Manifest permissions added: 9"
echo "Runtime permissions: 9"