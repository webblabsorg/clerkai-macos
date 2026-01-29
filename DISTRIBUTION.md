# Clerk macOS Distribution Guide

## Build Configurations

### Debug
- Local development
- Debug logging enabled
- Points to localhost API

### Release
- Production build
- Optimizations enabled
- Points to production API

## Code Signing

### Requirements
- Apple Developer Program membership
- Developer ID Application certificate
- Provisioning profile for Mac App Store (optional)

### Signing Identity
```bash
# List available signing identities
security find-identity -v -p codesigning

# Sign the app
codesign --force --deep --sign "Developer ID Application: Your Name (TEAM_ID)" Clerk.app
```

## Notarization

Apple requires notarization for apps distributed outside the Mac App Store.

### Steps

1. **Create ZIP for notarization**
```bash
ditto -c -k --keepParent Clerk.app Clerk.zip
```

2. **Submit for notarization**
```bash
xcrun notarytool submit Clerk.zip \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID" \
  --password "app-specific-password" \
  --wait
```

3. **Staple the ticket**
```bash
xcrun stapler staple Clerk.app
```

## Distribution Methods

### 1. Direct Download (DMG)

Create a DMG for direct distribution:

```bash
# Create DMG
create-dmg \
  --volname "Clerk" \
  --volicon "Clerk.app/Contents/Resources/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "Clerk.app" 150 190 \
  --hide-extension "Clerk.app" \
  --app-drop-link 450 185 \
  "Clerk-1.0.0.dmg" \
  "Clerk.app"
```

### 2. Mac App Store

1. Archive the app in Xcode
2. Validate the archive
3. Upload to App Store Connect
4. Submit for review

### 3. Sparkle Auto-Update

The app includes Sparkle for automatic updates.

**appcast.xml structure:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Clerk Updates</title>
    <item>
      <title>Version 1.0.1</title>
      <sparkle:version>2</sparkle:version>
      <sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>https://clerk.legal/releases/1.0.1.html</sparkle:releaseNotesLink>
      <pubDate>Mon, 01 Feb 2026 12:00:00 +0000</pubDate>
      <enclosure 
        url="https://clerk.legal/releases/Clerk-1.0.1.dmg"
        sparkle:edSignature="..."
        length="12345678"
        type="application/octet-stream"/>
    </item>
  </channel>
</rss>
```

## App Store Metadata

### App Name
Clerk - AI Legal Assistant

### Subtitle
301 AI Tools for Legal Professionals

### Description
Clerk is a lightweight, floating AI assistant designed specifically for legal professionals. It provides instant access to 301 specialized AI legal tools directly alongside your everyday work applications.

**Key Features:**
• Context-aware AI assistance
• 301 specialized legal tools
• Works with Word, PDF, Email, and more
• Contract risk analysis
• Legal research assistance
• Document summarization
• Multilingual support (50 languages)

### Keywords
legal, AI, assistant, contract, law, attorney, lawyer, document, analysis, research

### Category
Productivity

### Age Rating
4+

### Privacy Policy URL
https://clerk.legal/privacy

### Support URL
https://clerk.legal/support

## Screenshots Required

1. **Minimized State** - Avatar floating on desktop
2. **Compact Toolbar** - Quick action buttons
3. **Expanded Panel** - Full tool browser
4. **Tool Execution** - Risk analysis results
5. **Settings** - Theme options

## Review Guidelines Compliance

### Accessibility
- Full VoiceOver support
- Keyboard navigation
- High contrast mode support

### Privacy
- No data collection without consent
- Keychain for sensitive storage
- Clear privacy policy

### Security
- App Sandbox enabled
- Hardened Runtime
- No private API usage

## Release Checklist

- [ ] Update version number in Info.plist
- [ ] Update CHANGELOG.md
- [ ] Run all unit tests
- [ ] Run all UI tests
- [ ] Test on minimum supported macOS (12.0)
- [ ] Test on latest macOS
- [ ] Code sign with Developer ID
- [ ] Notarize the app
- [ ] Create DMG
- [ ] Update appcast.xml
- [ ] Upload to CDN
- [ ] Update website download links
- [ ] Announce release
