##
# - First, go to the Android Studio download page: https://developer.android.com/studio;
# - Then click in “Download Options”;
# - There you will find a table named “Command line tools only”;
# - This table contain some zip files. Download the appropriate file for your system (Windows, Mac or Linux);
# - Extract this zip and you will get a folder called tools: This is the tools package i explained earlier;
# - mkdir -p ~/Library/Android/sdk/cmdline-tools
# - mv ~/Downloads/cmdline-tools ~/Library/Android/sdk/cmdline-tools/latest
# - cd ~/Library/Android/sdk
# - ./cmdline-tools/latest/bin/sdkmanager --list
# - ./cmdline-tools/latest/bin/sdkmanager platform-tools emulator
# - curl -o ~/Downloads/commandlinetools.zip https://dl.google.com/android/repository/commandlinetools-mac-10406996_latest.zip && unzip ~/Downloads/commandlinetools.zip && mkdir -p ~/Library/Android/sdk/cmdline-tools && mv ~/Downloads/cmdline-tools ~/Library/Android/sdk/cmdline-tools/latest
#
# Install android 28
# - sdkmanager --install "platforms;android-33" "system-images;android-33;google_apis_playstore;arm64-v8a"
# - sdkmanager --list_installed
# - sdkmanager "platforms;android-28"
# - sdkmanager "build-tools;28.0.3"
# - sdkmanager "system-images;android-28;google_apis;x86_64"
# - avdmanager create avd --name test -d "pixel_5" -k "system-images;android-33;google_apis_playstore;arm64-v8a"
# - avdmanager create avd --name android28 — package "system-images;android-28;default;x86"
#
# Start emulator
# - emulator -list-avds
# - emulator @android28
# - adb devices
#
# Remove emulator
# - avdmanager delete avd -n android28
# - rm -rf ~/.android/avd/android28.avd
# - rm -rf ~/Library/Android/sdk/system-images/android-28
##

ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"

if [ -d "$ANDROID_SDK_ROOT" ]; then
  export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
  export ANDROID_HOME="$ANDROID_SDK_ROOT"
  export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
  export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"
  export PATH="$ANDROID_SDK_ROOT/emulator:$PATH"
fi
