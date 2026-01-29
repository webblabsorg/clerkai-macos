# Clerk macOS App - Setup Guide

## Prerequisites

- macOS 13.0+ (Ventura or later)
- Xcode 15.0+
- Apple Developer account (for signing and distribution)

## Initial Setup

### 1. Clone and Open Project

```bash
cd dev/macos
open Clerk.xcodeproj
```

### 2. Configure Signing

1. Open project settings in Xcode
2. Select "Clerk" target
3. Under "Signing & Capabilities":
   - Select your Team
   - Update Bundle Identifier to your registered App ID
   - Ensure "Automatically manage signing" is checked

### 3. Update Configuration Files

#### ExportOptions.plist
Edit `Clerk/Resources/ExportOptions.plist`:
- Replace `YOUR_TEAM_ID` with your Apple Developer Team ID

#### Sparkle Keys
Generate EdDSA keys for Sparkle updates:

```bash
# Download Sparkle framework
# https://sparkle-project.org/

# Generate keys
./bin/generate_keys

# This outputs:
# - Private key (store securely, NEVER commit)
# - Public key (add to Sparkle.plist)
```

Edit `Clerk/Resources/Sparkle.plist`:
- Replace `YOUR_EDDSA_PUBLIC_KEY_HERE` with generated public key
- Update `SUFeedURL` to your appcast URL

### 4. App Groups (for Safari Extension)

1. In Apple Developer Portal, create App Group: `group.com.clerk.legal`
2. Add App Groups capability to both main app and Safari extension targets
3. Select the created group

## Browser Extensions

### Chrome Extension

1. **Development Installation**:
   ```bash
   # Navigate to chrome://extensions/
   # Enable "Developer mode"
   # Click "Load unpacked"
   # Select: Clerk/Resources/BrowserExtensions/chrome/
   ```

2. **Native Messaging Host Registration**:
   ```bash
   # Copy manifest to Chrome's NativeMessagingHosts directory
   mkdir -p ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/
   cp Clerk/Resources/BrowserExtensions/chrome/com.clerk.legal.native.json \
      ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/
   ```

3. **Update Extension ID**:
   - After loading the extension, note the generated Extension ID
   - Update `com.clerk.legal.native.json` with the actual extension ID

### Firefox Extension

1. **Development Installation**:
   ```bash
   # Navigate to about:debugging
   # Click "This Firefox" > "Load Temporary Add-on"
   # Select: Clerk/Resources/BrowserExtensions/firefox/manifest.json
   ```

2. **Native Messaging Host Registration**:
   ```bash
   mkdir -p ~/Library/Application\ Support/Mozilla/NativeMessagingHosts/
   cp Clerk/Resources/BrowserExtensions/firefox/com.clerk.legal.native.json \
      ~/Library/Application\ Support/Mozilla/NativeMessagingHosts/
   ```

### Safari Extension

Safari extensions require a separate Xcode target:

1. **Create Extension Target**:
   - File > New > Target
   - Select "Safari Extension"
   - Name: "Clerk Safari Extension"
   - Language: Swift
   - Type: Safari App Extension

2. **Configure Extension**:
   - Add App Groups capability
   - Copy protocol implementations from `SafariExtensionHandler.swift`
   - Implement `SFSafariExtensionHandler` subclass

3. **Enable in Safari**:
   - Safari > Settings > Extensions
   - Enable "Clerk Safari Extension"

## Permissions

The app requires these permissions (configured in entitlements):

| Permission | Purpose |
|------------|---------|
| Accessibility | Read text from other apps |
| Input Monitoring | Global keyboard shortcuts |
| Automation | AppleScript for Word/Mail integration |

Users will be prompted on first use. Guide them to:
- System Settings > Privacy & Security > Accessibility
- System Settings > Privacy & Security > Input Monitoring

## Building

### Debug Build
```bash
xcodebuild -scheme Clerk -configuration Debug build
```

### Release Build
```bash
xcodebuild -scheme Clerk -configuration Release build
```

### Archive for Distribution
```bash
xcodebuild -scheme Clerk -configuration Release archive \
  -archivePath build/Clerk.xcarchive

xcodebuild -exportArchive \
  -archivePath build/Clerk.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist Clerk/Resources/ExportOptions.plist
```

## Notarization

For distribution outside the App Store:

```bash
# Submit for notarization
xcrun notarytool submit build/export/Clerk.app.zip \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "@keychain:AC_PASSWORD" \
  --wait

# Staple the ticket
xcrun stapler staple build/export/Clerk.app
```

## Sparkle Updates

### Appcast Setup

Create `appcast.xml` on your server:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Clerk Updates</title>
    <item>
      <title>Version 1.0.0</title>
      <sparkle:version>1.0.0</sparkle:version>
      <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
      <description>Initial release</description>
      <pubDate>Mon, 01 Jan 2024 00:00:00 +0000</pubDate>
      <enclosure 
        url="https://clerk.legal/releases/Clerk-1.0.0.zip"
        sparkle:edSignature="YOUR_SIGNATURE_HERE"
        length="12345678"
        type="application/octet-stream"/>
    </item>
  </channel>
</rss>
```

### Signing Updates

```bash
# Sign the update archive
./bin/sign_update Clerk-1.0.0.zip

# This outputs the edSignature to add to appcast.xml
```

## Localization

The app supports 10 languages:
- English (en)
- Spanish (es)
- French (fr)
- German (de)
- Portuguese - Brazil (pt-BR)
- Chinese Simplified (zh-Hans)
- Japanese (ja)
- Korean (ko)
- Italian (it)
- Dutch (nl)

To add more languages:
1. Edit `Clerk/Resources/Localizable.xcstrings`
2. Add translations for each string key
3. Test with: `defaults write com.clerk.legal AppleLanguages "(ja)"`

## Troubleshooting

### Native Messaging Not Working
- Verify host manifest path is correct
- Check Console.app for errors
- Ensure ClerkNativeHost binary exists and is executable

### Accessibility Permission Denied
- Remove app from Accessibility list
- Re-add and restart app
- Check if running from correct location (not Downloads)

### Hotkeys Not Registering
- Verify Input Monitoring permission
- Check for conflicts with system shortcuts
- Try different key combinations
