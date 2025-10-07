# To learn more about how to use Nix to configure your environment
# see: https://firebase.google.com/docs/studio/customize-workspace
{ pkgs, ... }: {
  # Which nixpkgs channel to use.
  channel = "stable-24.05"; # or "unstable"
  # Use https://search.nixos.org/packages to find packages
  packages = [
    pkgs.flutter # Add Flutter SDK
    pkgs.jdk17   # For Android development
    pkgs.unzip   # General utility
    pkgs.python3
    # For Android SDK command line tools if not managed by Flutter/Android Studio
    # pkgs.android-tools 
  ];
  # Sets environment variables in the workspace
  env = {
     # Example: If Android SDK is installed via Nix and not auto-detected by Flutter
     # ANDROID_SDK_ROOT = "${pkgs.android-sdk}/libexec/android-sdk";
  };
  idx = {
    # Search for the extensions you want on https://open-vsx.org/ and use "publisher.id"
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];
    workspace = {
      # Runs when a workspace is first created with this `dev.nix` file
      onCreate = {
        # Optional: Run flutter doctor to check setup
        flutter-doctor = "flutter doctor";
        flutter-setup1 = "cd ..;wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.32.0-stable.tar.xz && tar -xJvf ./flutter_linux_3.32.0-stable.tar.xz ";
      };
      # To run something each time the workspace is (re)started, use the `onStart` hook
    };
    # Enable previews and customize configuration
    previews = {
      enable = true;
      previews = {
        web = {
          command = ["/home/user/flutter/bin/flutter" "run" "--machine" "-d" "web-server" "--web-hostname" "0.0.0.0" "--web-port" "$PORT"];
          manager = "flutter";
        };
        # Android preview might require more setup for emulators within Project IDX
      #  android = {
      #      command = ["/home/user/flutter/bin/flutter" "run" "--machine" "-d" "android" "-d" "localhost:5555"];
      #      manager = "flutter";
      #    };
       };
    };
  };
}
