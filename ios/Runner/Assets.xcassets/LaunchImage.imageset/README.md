# Change the iOS Launch Image

This folder controls the image shown while the iOS app starts. It does not change
the Flutter Web homepage.

You need a Mac with Xcode to use the visual Xcode steps.

## Change it in Xcode

1. Copy the approved launch images to the Mac.
2. Open Terminal on the Mac.
3. Go to the project folder.
4. Run:

```bash
open ios/Runner.xcworkspace
```

5. Wait for Xcode to open.
6. In the left **Project Navigator**, open **Runner > Assets.xcassets**.
7. Click **LaunchImage**.
8. Drag each approved image into the matching image slot.
9. Do not place a small image in a large slot; use the required size shown by Xcode.
10. Click **Product > Clean Build Folder**.
11. Run the app on an iPhone simulator and confirm the image is not stretched,
    cropped incorrectly, or unreadable.
12. Save the project and commit only the intended asset changes.

## Change the files directly

1. Keep the existing file names and sizes unless `Contents.json` is deliberately updated.
2. Replace only the corresponding PNG files in this folder.
3. Open `Contents.json` and confirm every `filename` matches a real file.
4. Test in Xcode on the supported iPhone/iPad sizes.

Keep the original approved images in private design storage so they can be restored.
