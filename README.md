TODO: Move this stuff to a subfolder

# Emacs for Android

To allow Emacs on Android to access file from Termux,
they have to have the same user id and be signed by the
same key. There are precompiled emacs-apks that do that,
but the matching termux does not run on my phone.

The flake fetches both APKs from upstream (SourceForge + F-Droid),
patches the Emacs manifest with `sharedUserId`, and re-signs
both with a throwaway key.

# Usage

1. Check that the `flake.nix` download urls point to the input-apks that you want.
2. Run `nix build`
2. Install `result/emacs.apk` and `result/termux.apk` on the device

# Installing

1. Install Termux, don't open yet
2. Install Emacs
3. Open Termux, run `pkg update && pkgs upgrade`
4. Open Emacs, check (`find-file`) that it can access `/data/data/com.termux/...`
4. Create `/.emacs.d/early-init.el`:
```elisp
(when (string-equal system-type "android")
  ;; Add Termux binaries to PATH environment
  (let ((termuxpath "/data/data/com.termux/files/usr/bin"))
    (setenv "PATH" (concat (getenv "PATH") ":" termuxpath))
    (setq exec-path (append exec-path (list termuxpath)))))
```

# Sources

Termux (F-Droid): https://f-droid.org/packages/com.termux/
Emacs (Precompiled with Termux-User): https://sourceforge.net/projects/android-ports-for-gnu-emacs/files/termux/
Signing: https://marek-g.github.io/posts/tips_and_tricks/emacs_on_android/

