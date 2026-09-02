# Android SDK
#
# Homebrew lives under /opt/homebrew on Apple Silicon and /usr/local on Intel.
# Prefer a full Android Studio SDK when it exists, then fall back to the
# android-commandlinetools Homebrew formula.
for _android_sdk in \
    "$HOME/Library/Android/sdk" \
    "/opt/homebrew/share/android-commandlinetools" \
    "/usr/local/share/android-commandlinetools"
do
    if [[ -d "$_android_sdk" ]]; then
        export ANDROID_SDK_ROOT="$_android_sdk"
        export ANDROID_HOME="$ANDROID_SDK_ROOT"
        export ANDROID_AVD_HOME="$HOME/.android/avd"
        path=(
            "$ANDROID_SDK_ROOT/platform-tools"
            "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
            "$ANDROID_SDK_ROOT/emulator"
            $path
        )
        break
    fi
done
unset _android_sdk
