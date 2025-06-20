#!/bin/bash
# This script sets up the Android development environment.

# Function to check if Git is installed
check_git() {
  echo "Checking for Git..."
  if ! command -v git &> /dev/null; then
    echo "Git is not installed. Please install Git to continue."
    echo "Download Git from: https://git-scm.com/downloads"
    exit 1
  else
    echo "Git is installed."
  fi
}

# Function to check if Android SDK is configured
check_android_sdk() {
  echo "Checking for Android SDK..."
  if [ -z "$ANDROID_HOME" ]; then
    echo "ANDROID_HOME environment variable is not set."
    echo "Please install the Android SDK and set ANDROID_HOME to your SDK installation directory."
    echo "Download Android SDK from: https://developer.android.com/sdk/installing/index.html"
    echo "Remember to add \$ANDROID_HOME/tools and \$ANDROID_HOME/platform-tools to your PATH."
    exit 1
  else
    echo "ANDROID_HOME is set to: $ANDROID_HOME"

    # Check for essential tools
    if [ ! -x "$ANDROID_HOME/tools/bin/sdkmanager" ]; then
      echo "sdkmanager not found or not executable at \$ANDROID_HOME/tools/bin/sdkmanager."
      echo "Please ensure your Android SDK installation is correct."
      exit 1
    fi

    if [ ! -x "$ANDROID_HOME/platform-tools/adb" ]; then
      echo "adb not found or not executable at \$ANDROID_HOME/platform-tools/adb."
      echo "Please ensure your Android SDK installation is correct."
      exit 1
    fi
    echo "Essential Android SDK tools (sdkmanager, adb) found."

    # Check for required SDK packages
    echo "Checking for required SDK packages..."
    local installed_packages
    installed_packages=$("$ANDROID_HOME/tools/bin/sdkmanager" --list_installed)

    local build_tools_version="24.0.2"
    local platform_version="android-24"

    if ! echo "$installed_packages" | grep -q "build-tools;$build_tools_version"; then
      echo "Build tools version $build_tools_version not found."
      echo "Please install it using the SDK Manager: sdkmanager \"build-tools;$build_tools_version\""
      exit 1
    fi
    echo "Build tools version $build_tools_version found."

    if ! echo "$installed_packages" | grep -q "platforms;$platform_version"; then
      echo "Platform $platform_version not found."
      echo "Please install it using the SDK Manager: sdkmanager \"platforms;$platform_version\""
      exit 1
    fi
    echo "Platform $platform_version found."

    echo "Android SDK is correctly configured."
  fi
}

# Function to check for Android Studio installation
check_android_studio() {
  echo "Checking for Android Studio..."
  local found_android_studio=false
  # Common Linux paths
  if [ -f "/opt/android-studio/bin/studio.sh" ] || [ -f "$HOME/android-studio/bin/studio.sh" ]; then
    echo "Android Studio found in a common Linux path."
    found_android_studio=true
  fi

  # Common macOS path
  if [ -d "/Applications/Android Studio.app" ]; then
    echo "Android Studio found in /Applications."
    found_android_studio=true
  fi

  if [ "$found_android_studio" = false ]; then
    echo "Android Studio not found in common installation paths."
    echo "For a better development experience, consider installing Android Studio."
    echo "Download Android Studio from: https://developer.android.com/studio"
    # This is a non-blocking suggestion, so the script continues.
  fi
}

# Main script execution
echo "Starting Android Development Environment Setup..."

# Function to clone the project repository and set up remotes
setup_project_repo() {
  echo "-----------------------------------------------------"
  echo "Setting up the project repository..."
  local github_username
  read -p "Enter your GitHub username: " github_username

  if [ -z "$github_username" ]; then
    echo "GitHub username cannot be empty. Exiting."
    exit 1
  fi

  echo "Cloning the repository https://github.com/$github_username/android.git..."
  if [ -d "android" ]; then
    echo "The 'android' directory already exists."
    read -p "Skip cloning and try to set up remotes in existing directory? (y/n): " skip_clone
    if [ "$skip_clone" != "y" ]; then
      echo "Exiting. Please remove or rename the 'android' directory and rerun the script."
      exit 1
    fi
  else
    git clone "https://github.com/$github_username/android.git"
    if [ $? -ne 0 ]; then
      echo "Failed to clone the repository. Please check the username and repository URL. Exiting."
      exit 1
    fi
  fi

  cd android
  if [ $? -ne 0 ]; then
    echo "Failed to change directory to 'android'. Exiting."
    exit 1
  fi

  echo "Setting up upstream remote..."
  # Check if upstream remote already exists
  if git remote -v | grep -q "upstream"; then
    echo "Upstream remote already exists."
  else
    git remote add upstream https://github.com/nextcloud/android.git
    if ! git remote -v | grep -q "upstream.*https://github.com/nextcloud/android.git"; then
      echo "Failed to add upstream remote. Please check your Git configuration."
      # Not exiting here, as the primary clone might still be useful.
    else
      echo "Upstream remote added successfully."
    fi
  fi

  echo "Project repository cloned and remotes configured."
  echo "-----------------------------------------------------"
}

# Function to show build instructions
show_build_instructions() {
  echo "-----------------------------------------------------"
  echo "Build Instructions"
  echo "-----------------------------------------------------"
  echo "You should now be in the 'android' directory (cloned from your fork)."
  echo "If not, please 'cd android'."
  echo ""
  echo "To build the project, run the following command:"
  echo "  ./gradlew clean build"
  echo ""
  echo "For Windows users, the command is usually:"
  echo "  gradlew.bat clean build"
  echo ""
  echo "The first build can take a significant amount of time as Gradle needs to download dependencies."
  echo "Please be patient."
  echo ""
  echo "After a successful build, the generated APK files can be found in the:"
  echo "  app/build/outputs/apk/"
  echo "directory."
  echo ""
  echo "Inside this 'apk' directory, you will find subdirectories for each build flavor and type."
  echo "For example:"
  echo "  - app/build/outputs/apk/generic/debug/   (for the 'generic' flavor, 'debug' build type)"
  echo "  - app/build/outputs/apk/gplay/release/   (for the 'gplay' flavor, 'release' build type)"
  echo ""
  echo "A common debug APK for the 'generic' flavor might be located at a path like:"
  echo "  app/build/outputs/apk/generic/debug/app-generic-debug.apk"
  echo "(The exact filename might include version codes, e.g., app-generic-debug-[versionCode].apk)"
  echo ""
  echo "Please navigate into these directories to find the desired APK file."
  echo ""
  echo "For more details on contributing, please see the CONTRIBUTING.md file in the repository."
  echo "Happy coding!"
  echo "-----------------------------------------------------"
}

# Main script execution
echo "Starting Android Development Environment Setup..."

check_git
check_android_sdk
# Function to show common troubleshooting tips
show_troubleshooting_tips() {
  echo "-----------------------------------------------------"
  echo "Troubleshooting"
  echo "-----------------------------------------------------"
  echo "1. Java Heap Space (OutOfMemoryError):"
  echo "   If you encounter a 'java.lang.OutOfMemoryError: Java heap space' error during the Gradle build,"
  echo "   it means Gradle needs more memory. You can increase the heap size in a couple of ways:"
  echo ""
  echo "   a) Modify 'gradle.properties':"
  echo "      Add or update the following line in your project's 'gradle.properties' file"
  echo "      (or your global ~/.gradle/gradle.properties file):"
  echo "        org.gradle.jvmargs=-Xmx4G"
  echo ""
  echo "   b) Use an environment variable for a single command:"
  echo "      GRADLE_OPTS=\"-Xmx4G\" ./gradlew clean build"
  echo ""
  echo "   You can try '4G' as a starting point, but adjust this value (e.g., -Xmx2G, -Xmx6G) "
  echo "   depending on your system's available memory."
  echo ""
  echo "2. Other Issues:"
  echo "   If you encounter other issues, please first double-check all installation steps outlined"
  echo "   in the SETUP.MD file in the project repository."
  echo "   You can also search for existing issues or report new ones on the project's GitHub page."
  echo "-----------------------------------------------------"
}

# Main script execution
echo "Starting Android Development Environment Setup..."

check_git
check_android_sdk
check_android_studio
setup_project_repo
show_build_instructions
show_troubleshooting_tips

echo ""
echo "Setup script complete! You should now have the necessary dependencies checked/suggested and the project cloned."
echo "Follow the build instructions above to compile the app."
echo "Happy coding!"

exit 0
