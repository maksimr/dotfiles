##
# - First, go to the Android Studio download page: https://developer.android.com/studio;
# - Then click in “Download Options”;
# - There you will find a table named “Command line tools only”;
# - This table contain some zip files. Download the appropriate file for your system (Windows, Mac or Linux);
# - Extract this zip and you will get a folder called tools: This is the tools package i explained earlier;
# - mkdir -p ~/Library/Android/sdk
# - cd ~/Library/Android/sdk/cmdline-tools/
# - ./bin/sdkmanager --list --sdk_root=$(pwd)
# - ./bin/sdkmanager platform-tools emulator --sdk_root=$(pwd)
#
# Install android 28
# - sdkmanager "platforms;android-28"
# - sdkmanager "build-tools;28.0.3"
# - sdkmanager "system-images;android-28;google_apis;x86_64"
# - avdmanager create avd — name android28 — package "system-images;android-28;default;x86"
#
# Start emulator
# - emulator @android28
# - adb devices
#
# Remove emulator
# - avdmanager delete avd -n android28
# - rm -rf ~/.android/avd/android28.avd
# - rm -rf ~/Library/Android/sdk/system-images/android-28
##

ANDROID_SDK_ROOT="~/Library/Android/sdk/cmdline-tools"

if [ -d "$ANDROID_SDK_ROOT" ]; then
  export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
  export ANDROID_HOME="$ANDROID_SDK_ROOT"
  export PATH="$ANDROID_SDK_ROOT/tools/bin:$PATH"
  export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"
  export PATH="$ANDROID_SDK_ROOT/emulator:$PATH"
fi
