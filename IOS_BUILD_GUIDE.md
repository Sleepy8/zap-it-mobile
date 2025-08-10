# iOS Build Guide for Codemagic

## Problem
Your Codemagic build was not generating IPA files because the `--no-codesign` flag prevents IPA creation.

## Solutions

### Option 1: Development Build with Code Signing (Recommended)
**Workflow**: `ios-development`

This workflow will generate an IPA file that you can download and install on devices.

**Requirements**:
1. Apple Developer Account (free or paid)
2. Code signing certificates
3. Provisioning profiles

**Setup in Codemagic**:
1. Go to your Codemagic project settings
2. Navigate to "Team Settings" > "Code signing identities"
3. Add your iOS certificates and provisioning profiles
4. Update the following variables in the workflow:
   - `CM_CERTIFICATE`: Your certificate name
   - `CM_CERTIFICATE_PASSWORD`: Your certificate password
   - `CM_PROVISIONING_PROFILE`: Your provisioning profile name

### Option 2: Test Build without Code Signing
**Workflow**: `ios-test-build`

This workflow builds the app but doesn't create an IPA file. It's useful for testing the build process.

**Output**: `.app` files (not installable on devices)

### Option 3: Device Build for App Store
**Workflow**: `ios-device-build`

This workflow creates a release IPA for App Store distribution.

## Current Configuration

Your `codemagic.yaml` now includes:

1. **ios-development**: Creates IPA with code signing (requires setup)
2. **ios-test-build**: Creates .app files without code signing (no setup required)
3. **ios-device-build**: Creates release IPA for App Store

## Quick Fix for Immediate Testing

If you want to test the build process immediately without setting up code signing:

1. Use the `ios-test-build` workflow
2. This will create `.app` files instead of `.ipa`
3. You can verify the build works without needing certificates

## To Get IPA Files

To get downloadable IPA files, you need to:

1. **Set up code signing in Codemagic**:
   - Add your Apple Developer certificates
   - Add your provisioning profiles
   - Update the workflow variables

2. **Use the `ios-development` workflow**:
   - This will create an IPA file
   - The IPA will be available for download in Codemagic

## Export Options Files

- `ios/exportOptions.plist`: For App Store distribution
- `ios/exportOptions-adhoc.plist`: For development/ad-hoc distribution

## Next Steps

1. **For immediate testing**: Use `ios-test-build` workflow
2. **For IPA files**: Set up code signing and use `ios-development` workflow
3. **For App Store**: Use `ios-device-build` workflow

## Common Issues

- **No IPA generated**: Make sure you're not using `--no-codesign` flag
- **Code signing errors**: Verify certificates and provisioning profiles in Codemagic
- **Team ID issues**: Ensure `CM_TEAM_ID` matches your Apple Developer Team ID
