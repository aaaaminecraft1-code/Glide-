# Glide — motion + Liquid Glass app

A small iPhone app that shows off smooth motion and very clear Liquid Glass.

- **Cards** – tap a card and it zooms open full screen. Tap X (or swipe down) and it shrinks back into its spot. Cards squish when pressed and blur away as you scroll.
- **+ button** – glass buttons melt out of it and back in.
- **Glass** – drag a big glass drop over moving colours and words. Let go and it springs back.
- **Settings** – switch glass between Clear and Regular, and choose how bouncy every animation is.

Needs **iOS 26 or newer**.

---

## Get the .ipa (no Mac needed)

GitHub builds the .ipa for you on a free Mac in the cloud.

1. Make a free account at github.com and create a **new repository** (any name, e.g. `Glide`).
2. Unzip this project. In the repository, tap **Add file → Upload files** and upload everything inside the `Glide` folder.
   - Make sure the hidden folder `.github` is uploaded too. If it doesn't show up, use **Add file → Create new file**, name it `.github/workflows/build-ipa.yml`, and paste in that file's text.
3. Open the **Actions** tab. "Build IPA" starts by itself (or tap **Run workflow**). It takes about 5 minutes.
4. When it shows a green tick, open the run, scroll to **Artifacts**, and download **Glide-ipa**. Unzip it to get **Glide.ipa**.

## Put it on your iPhone

You need a computer (Windows or Mac) for this step.

1. Install **Sideloadly** from sideloadly.io.
   On Windows, also install **iTunes** and **iCloud** from apple.com (not the Microsoft Store versions).
2. Plug in your iPhone, drag **Glide.ipa** into Sideloadly, type your Apple ID, and press **Start**.
3. On the iPhone:
   - **Settings → Privacy & Security → Developer Mode → On** (the phone restarts).
   - **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.
4. Open Glide.

With a free Apple ID the app stops opening after **7 days**. Just install it again with Sideloadly — your settings stay.

---

## On a Mac with Xcode instead

1. Install **Xcode 26** from the Mac App Store, and Homebrew from brew.sh.
2. In Terminal, inside this folder:
   ```
   brew install xcodegen
   xcodegen generate
   open Glide.xcodeproj
   ```
3. Click **Glide** in the left bar → **Signing & Capabilities** → choose your Apple ID as the Team.
   If it says the bundle ID is taken, change `com.glide.motionapp` to something unique, like `com.yourname.glide`.
4. Plug in your iPhone, pick it at the top, and press **▶ Run**. Do the Developer Mode and Trust steps above.

---

## Files

| File | What it is |
|---|---|
| `Glide/GlideApp.swift` | All the app code |
| `Glide/Assets.xcassets` | App icon |
| `project.yml` | Recipe that creates the Xcode project |
| `.github/workflows/build-ipa.yml` | Tells GitHub how to build the .ipa |
