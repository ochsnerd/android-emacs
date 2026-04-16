{
  description = "Re-sign Emacs & Termux APKs with shared key for sharedUserId";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.android_sdk.accept_license = true;
      };

      androidSdk = pkgs.androidenv.composeAndroidPackages {
        buildToolsVersions = [ "37.0.0" ];
        includeEmulator = false;
        includeSources = false;
        includeSystemImages = false;
      };

      buildTools = "${androidSdk.androidsdk}/libexec/android-sdk/build-tools/37.0.0";

      emacsApk = pkgs.fetchurl {
        url = "https://sourceforge.net/projects/android-ports-for-gnu-emacs/files/termux/emacs-31.0.50-35-arm64-v8a.apk/download";
        name = "emacs-31.0.50-35-arm64-v8a.apk";
        sha256 = "1if65ihsq4jmrvw4ibn9fz0qmzi3mr7xjnlff8pczihgl21zhb76";
      };

      termuxApk = pkgs.fetchurl {
        url = "https://f-droid.org/repo/com.termux_1002.apk";
        sha256 = "1v1722qn7cs930l0v2hcpj9yv2wmalcv1qw8hj0678swxdbml9p6";
      };
    in
    {
      packages.${system}.default = pkgs.stdenv.mkDerivation {
        name = "android-emacs-termux-signed";

        dontUnpack = true;

        nativeBuildInputs = [
          pkgs.apktool
          pkgs.jdk17
        ];

        buildPhase = ''
          export HOME=$TMPDIR

          # Unpack both APKs
          apktool d -f -o emacs ${emacsApk}
          apktool d -f -o termux ${termuxApk}

          # Patch Emacs manifest: add sharedUserId if not already present
          if ! grep -q 'android:sharedUserId' emacs/AndroidManifest.xml; then
            sed -i 's|<manifest |<manifest android:sharedUserId="com.termux" android:sharedUserLabel="@string/shared_user_name" |' emacs/AndroidManifest.xml
          fi

          # Add shared_user_name string resource if not present
          if ! grep -q 'shared_user_name' emacs/res/values/strings.xml; then
            sed -i 's|</resources>|    <string name="shared_user_name">Termux user</string>\n</resources>|' emacs/res/values/strings.xml
          fi

          # Rebuild both APKs
          apktool b emacs -o emacs-unsigned.apk
          apktool b termux -o termux-unsigned.apk

          # Zipalign (before signing)
          ${buildTools}/zipalign -f -p 4 emacs-unsigned.apk emacs-aligned.apk
          ${buildTools}/zipalign -f -p 4 termux-unsigned.apk termux-aligned.apk

          # Generate throwaway keystore
          keytool -genkeypair \
            -keystore signing.keystore \
            -alias key \
            -keyalg RSA \
            -keysize 2048 \
            -validity 10000 \
            -storepass android \
            -keypass android \
            -dname "CN=Android,O=Android,C=US"

          # Sign both with the same key
          ${buildTools}/apksigner sign \
            --ks signing.keystore \
            --ks-pass pass:android \
            --ks-key-alias key \
            --key-pass pass:android \
            --out emacs-signed.apk \
            emacs-aligned.apk

          ${buildTools}/apksigner sign \
            --ks signing.keystore \
            --ks-pass pass:android \
            --ks-key-alias key \
            --key-pass pass:android \
            --out termux-signed.apk \
            termux-aligned.apk
        '';

        installPhase = ''
          mkdir -p $out
          cp emacs-signed.apk $out/emacs.apk
          cp termux-signed.apk $out/termux.apk
        '';
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.jdk17
          pkgs.apktool
          androidSdk.androidsdk
        ];

        shellHook = ''
          export ANDROID_SDK_ROOT="${androidSdk.androidsdk}/libexec/android-sdk"
          export PATH="$ANDROID_SDK_ROOT/build-tools/37.0.0:$PATH"
        '';
      };
    };
}
