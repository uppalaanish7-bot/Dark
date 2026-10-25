# HERO — platform builds

The current source is **The Hollow Spire**, with Girl Knight and Omega Knight, an AI partner, sword-and-magic combat, and eleven sequential guardian floors connected by a central lift. See [README.md](README.md) for controls and gameplay.

## Windows

The existing `build/Hero.exe` and `Hero.pck` predate the tower progression changes. Rebuild with `powershell -File tools/package_windows.ps1` to include them. Keep the executable, resource pack and included attribution notices together. The portable package uses the installed official Godot 4.7.2 runtime.

The scene uses Godot's GL Compatibility renderer. Settings includes a 3D render-scale slider for slower graphics hardware. Interface resolution stays sharp when scene resolution is lowered.

## Android

The signed phone package is `build/android/Hero.apk`. It includes both playable knights, icon controls, and sword-and-magic combat. The package predates the current tower progression changes and needs rebuilding before it reflects the eleven-floor lift game. Transfer the APK to your Android phone, open it from Files, allow that app to install unknown apps if Android asks, and select Install. Launch **Hero** from your app list. The game runs offline and requests no Android permissions.

This build requires a **64-bit ARM Android phone**, Android 7.0 or later (API 24+), and OpenGL ES 3.0. It targets Android API 36. Hold the phone horizontally; either landscape rotation works. Mobile rendering defaults to 75% 3D resolution with a 60 fps cap; change Render scale in Settings to suit the phone. The interface remains at full resolution. Frame rate and thermal behavior depend on the phone.

Use the left stick to move and run, swipe the open right side to look, and tap the circular action icons. The large sword is attack; the jumping figure is jump; the rolling figure is dodge. Fire or lightning, enchantment and meteor or storm icons follow the selected knight. The in-game help screen explains the controls. Pause and menu transitions release held touches.

APK signature, manifest, ARM64 contents, 16 KB ZIP alignment and native ELF page alignment are verified by the packaging script. Its isolated resource check loads the actual exported runtime roots and instantiates all 24 actor scenes from the APK payload. `build/android/verification.json` records the version, size, signing-certificate fingerprint and SHA-256; `Hero.apk.sha256` is the transferable checksum. No phone or configured emulator was available for installation, performance or thermal testing. Desktop touch validation is separate from device testing.

Rebuild with Godot 4.7.2, matching Android export templates, an Android SDK and Java 17+:

```powershell
powershell -File tools/package_android.ps1
```

`package_android.ps1` discovers the SDK and JDK, including the JDK bundled with the VS Code Java extension. Override paths with `-JavaHome`, `-AndroidHome` and `-Godot` if needed. It generates Hero icons, selects runtime roots and their dependencies, and creates a separate project under `build/android/staging`. Material textures in this Android-only stage use ETC2 compression and a 1024-pixel maximum dimension; UI assets retain their full resolution. Source art and desktop import settings remain unchanged. `-TextureLimit 2048` can trade a larger phone download and GPU-memory use for more texture detail.

The script exports to a temporary APK, repairs the Godot template's duplicated AndroidX provider authority, realigns and signs it, verifies the result and only then replaces `Hero.apk`. Runtime checks use `build/android/runtime-check.zip`, assembled from the APK's assets with a temporary checker, so missing resources cannot silently load from the source project. Detailed build diagnostics and the explicit resource manifest are kept in `build/android/`. Model attribution, animation/font notices and Godot engine/third-party licenses are included inside the APK and alongside it.

The application ID remains `com.northstar.relicarena`. This release is **1.1.0**, version code **2**. Increase `version/code` in `export_presets.cfg` before distributing a later update.

No previous release key was present on this computer, so the build creates a local release key under `%LOCALAPPDATA%/RELIC/signing` and reuses it thereafter. Its password is protected by Windows DPAPI for this Windows account. Keep a secure backup of the signing material; it is deliberately excluded from the project and phone package. An older installation signed with a different, unavailable key cannot be updated in place. Recover that original key to preserve update continuity and app data.

## Web

Web packaging has not been refreshed or verified for this release.

