{
    description = "Flutter dev environment";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
        flake-parts.url = "github:hercules-ci/flake-parts";
    };

    outputs = inputs @ {flake-parts, ...}:
        flake-parts.lib.mkFlake {inherit inputs;} {
            systems = ["x86_64-linux"];

            perSystem = {system, ...}: let
                pkgs = import inputs.nixpkgs {
                    inherit system;
                    config = {
                        allowUnfree = true;
                        android_sdk.accept_license = true;
                    };
                };

                androidComposition = pkgs.androidenv.composeAndroidPackages {
                    platformToolsVersion = "35.0.2";
                    buildToolsVersions = ["35.0.0" "34.0.0"];
                    platformVersions = ["36" "35" "34" "30"];
                    abiVersions = ["x86_64"];

                    includeEmulator = true;
                    emulatorVersion = "35.6.9";
                    includeSystemImages = true;
                    systemImageTypes = ["google_apis_playstore"];

                    includeNDK = true;
                    ndkVersions = ["28.2.13676358"];

                    extraLicenses = [
                        "android-sdk-license"
                        "android-sdk-preview-license"
                        "google-gdk-license"
                        "intel-android-extra-license"
                        "intel-android-sysimage-license"
                    ];
                };

                androidSdk = androidComposition.androidsdk;
                mesaLib = pkgs.mesa;
                glvndLib = pkgs.libglvnd;
            in {
                devShells.default = pkgs.mkShell {
                    # Env vars — ter-set saat direnv load
                    ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
                    ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
                    JAVA_HOME = "${pkgs.jdk17}";

                    packages = with pkgs; [
                        flutter
                        firebase-tools
                        androidSdk
                        jdk17
                        mesa
                        libglvnd
                        pkg-config
                        cmake
                        ninja
						opencode
                    ];

                    shellHook = ''
                        export PATH=$HOME/.pub-cache/bin:$PATH
                        export VK_ICD_FILENAMES="${mesaLib}/share/vulkan/icd.d/intel_icd.x86_64.json"
                        export LD_LIBRARY_PATH="${glvndLib}/lib:${mesaLib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
                        export LIBGL_DRIVERS_PATH="${mesaLib}/lib/dri"
                        export EGL_PLATFORM=x11
                        export PKG_CONFIG_EXECUTABLE="${pkgs.pkg-config}/bin/pkg-config"
                        export DISPLAY="''${DISPLAY:-:0}"
                        export QT_QPA_PLATFORM=xcb
                        export ANDROID_AAPT2="${androidSdk}/libexec/android-sdk/build-tools/35.0.0/aapt2"
                        export ANDROID_CMAKE="${pkgs.cmake}/bin/cmake"
                        export ANDROID_AVD_HOME="$HOME/.android/avd"
                        export ANDROID_EMULATOR_HOME="$HOME/.android"
                        export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/35.0.0/aapt2"

                        if [ -f android/gradle.properties ]; then
                          sed -i './gamesbox_kids/android.aapt2FromMavenOverride/d' ./gamesbox_kids/android/gradle.properties
                          sed -i './gamesbox_parent/android.aapt2FromMavenOverride/d' ./gamesbox_parent/android/gradle.properties
                          echo "android.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/35.0.0/aapt2" >> ./gamesbox_kids/android/gradle.properties
                          echo "android.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/35.0.0/aapt2" >> ./gamesbox_parent/android/gradle.properties
                        fi

                        {
                          echo "sdk.dir=$ANDROID_SDK_ROOT"
                          echo "cmake.dir=${pkgs.cmake}"
                          echo "ndk.dir=$ANDROID_SDK_ROOT/ndk/28.2.13676358"
                          echo "flutter.sdk=${pkgs.flutter}"
                        } > ./gamesbox_kids/android/local.properties

                        {
                          echo "sdk.dir=$ANDROID_SDK_ROOT"
                          echo "cmake.dir=${pkgs.cmake}"
                          echo "ndk.dir=$ANDROID_SDK_ROOT/ndk/28.2.13676358"
                          echo "flutter.sdk=${pkgs.flutter}"
                        } > ./gamesbox_parent/android/local.properties
                    '';
                };
            };
        };
}
