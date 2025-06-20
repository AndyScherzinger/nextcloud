#!/bin/bash -e
# Internal script for setting up Android SDK and building the project in a CI/subtask environment.

echo "Starting internal Android build setup..."

# Ensure JAVA_HOME is set and JDK 17 is used
echo "Checking for Java 17..."
# Try to update package lists, proceed even if it fails (e.g. no permissions for sudo)
if command -v sudo &> /dev/null; then
    sudo apt-get update -y || echo "Warning: apt-get update failed. Proceeding with Java check/install."
else
    echo "sudo not found. Assuming apt-get update is not needed or will be handled manually."
fi

# Check current Java version
JAVA_VERSION_OUTPUT=$(java -version 2>&1 || echo "Java not found")
if echo "$JAVA_VERSION_OUTPUT" | grep -q "version \"17\." ; then
    echo "Java 17 is already installed."
    # Try to set JAVA_HOME if it's not already set, assuming a common path for OpenJDK 17
    if [ -z "$JAVA_HOME" ] && [ -d "/usr/lib/jvm/java-17-openjdk-amd64" ]; then
        export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
        export PATH=$JAVA_HOME/bin:$PATH
        echo "JAVA_HOME heuristically set to /usr/lib/jvm/java-17-openjdk-amd64"
    elif [ -z "$JAVA_HOME" ]; then
        # Attempt to find java home
        JAVA_INSTALL_PATH=$(dirname $(dirname $(readlink -f $(which java))))
        if [ -d "$JAVA_INSTALL_PATH" ]; then
             export JAVA_HOME=$JAVA_INSTALL_PATH
             export PATH=$JAVA_HOME/bin:$PATH
             echo "JAVA_HOME set to $JAVA_HOME"
        fi
    fi
else
    echo "Java 17 not found or version mismatch. Attempting to install OpenJDK 17..."
    if command -v sudo &> /dev/null; then
        sudo apt-get install -y openjdk-17-jdk || { echo "Failed to install OpenJDK 17 automatically via apt-get. Please ensure JDK 17 is installed and JAVA_HOME is set."; exit 1; }
        # Set JAVA_HOME for OpenJDK 17 installed via apt
        if [ -d "/usr/lib/jvm/java-17-openjdk-amd64" ]; then
            export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
            export PATH=$JAVA_HOME/bin:$PATH
        else
            echo "OpenJDK 17 was installed, but JAVA_HOME could not be set automatically. Please set it manually."
            # Attempt to find java home
            JAVA_INSTALL_PATH=$(dirname $(dirname $(readlink -f $(which java))))
             if [ -d "$JAVA_INSTALL_PATH" ]; then
                export JAVA_HOME=$JAVA_INSTALL_PATH
                export PATH=$JAVA_HOME/bin:$PATH
                echo "JAVA_HOME set to $JAVA_HOME after installation attempt"
            else
                exit 1 # Exit if JAVA_HOME still cannot be determined
            fi
        fi
    else
        echo "sudo not found. Cannot install OpenJDK 17 automatically. Please ensure JDK 17 is installed and JAVA_HOME is set."
        exit 1
    fi
fi
echo "JAVA_HOME is currently set to: $JAVA_HOME"
echo "Current Java version:"
java -version

# Define SDK installation directory and Command-Line Tools URL
ANDROID_SDK_ROOT="/opt/android-sdk"
# Check https://developer.android.com/studio#command-line-tools-only for latest version if this fails
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

# Download and Unzip Command-Line Tools
echo "Downloading Android command-line tools..."
# Use sudo to create directory in /opt
if command -v sudo &> /dev/null; then
    sudo mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools"
    # Ensure the current user has ownership to write into it later if needed, or run subsequent commands with sudo
    sudo chown -R "$(whoami):$(whoami)" "${ANDROID_SDK_ROOT}" || echo "Warning: Failed to chown ${ANDROID_SDK_ROOT}. SDK setup might require sudo for all file operations."
else
    echo "sudo not found. Attempting to create SDK directory without sudo. This might fail."
    mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools"
fi


# Ensure curl and unzip are installed
if ! command -v curl &> /dev/null || ! command -v unzip &> /dev/null; then
  echo "curl and/or unzip are not installed. Attempting to install..."
  if command -v sudo &> /dev/null && command -v apt-get &> /dev/null; then
    sudo apt-get update -y && sudo apt-get install -y curl unzip
  elif command -v sudo &> /dev/null && command -v yum &> /dev/null; then
    sudo yum install -y curl unzip
  elif command -v sudo &> /dev/null && command -v dnf &> /dev/null; then
    sudo dnf install -y curl unzip
  elif command -v yum &> /dev/null; then # Fallback for environments where sudo might not be needed for yum/dnf
    yum install -y curl unzip
  elif command -v dnf &> /dev/null; then
    dnf install -y curl unzip
  else
    echo "Could not find a known package manager (apt-get, yum, dnf with sudo capabilities or direct execution) to install curl/unzip. Please install them manually."
    exit 1
  fi
fi

# Download to /tmp which should be writable
curl -L -o /tmp/cmdline-tools.zip "${CMDLINE_TOOLS_URL}"
# Check if download was successful
if [ ! -f /tmp/cmdline-tools.zip ] || [ ! -s /tmp/cmdline-tools.zip ]; then
    echo "Failed to download command-line tools. Please check the URL: ${CMDLINE_TOOLS_URL}"
    exit 1
fi

# Unzip and move with sudo if ANDROID_SDK_ROOT is in /opt or other protected location
if [[ "${ANDROID_SDK_ROOT}" == /opt/* ]] && command -v sudo &> /dev/null; then
    sudo unzip -q /tmp/cmdline-tools.zip -d "${ANDROID_SDK_ROOT}/cmdline-tools"
    if [ -d "${ANDROID_SDK_ROOT}/cmdline-tools/latest" ]; then
      sudo rm -rf "${ANDROID_SDK_ROOT}/cmdline-tools/latest"
    fi
    # Check if the cmdline-tools directory was created by unzip
    if [ ! -d "${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools" ]; then
        echo "Unzip did not create the expected 'cmdline-tools/cmdline-tools' directory within ${ANDROID_SDK_ROOT}/cmdline-tools."
        echo "Contents of ${ANDROID_SDK_ROOT}/cmdline-tools:"
        sudo ls -la "${ANDROID_SDK_ROOT}/cmdline-tools" # Use sudo to list if needed
        exit 1
    fi
    sudo mv "${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools" "${ANDROID_SDK_ROOT}/cmdline-tools/latest"
else # Attempt without sudo if not in /opt or sudo not available
    unzip -q /tmp/cmdline-tools.zip -d "${ANDROID_SDK_ROOT}/cmdline-tools"
    if [ -d "${ANDROID_SDK_ROOT}/cmdline-tools/latest" ]; then
      rm -rf "${ANDROID_SDK_ROOT}/cmdline-tools/latest"
    fi
    if [ ! -d "${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools" ]; then
        echo "Unzip did not create the expected 'cmdline-tools/cmdline-tools' directory within ${ANDROID_SDK_ROOT}/cmdline-tools."
        echo "Contents of ${ANDROID_SDK_ROOT}/cmdline-tools:"
        ls -la "${ANDROID_SDK_ROOT}/cmdline-tools"
        exit 1
    fi
    mv "${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools" "${ANDROID_SDK_ROOT}/cmdline-tools/latest"
fi
rm /tmp/cmdline-tools.zip
echo "Android command-line tools downloaded and extracted."

# Set Environment Variables
echo "Setting up ANDROID_HOME and PATH..."
export ANDROID_HOME="${ANDROID_SDK_ROOT}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT}"
export PATH="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${PATH}"
# Ensure JAVA_HOME/bin is also in PATH, done during Java setup but re-iterate for safety
if [ -n "$JAVA_HOME" ]; then
    export PATH="$JAVA_HOME/bin:$PATH"
fi

echo "ANDROID_HOME set to: ${ANDROID_HOME}"
echo "PATH updated."
# echo "Current PATH: ${PATH}" # For debugging

# Install SDK packages using sdkmanager
# sdkmanager needs write access to ANDROID_SDK_ROOT. If it's in /opt, sdkmanager might need to be run with sudo,
# or permissions need to be set correctly. The chown above helps, but let's ensure sdkmanager itself has permissions.
# A common practice for CI is to run sdkmanager itself as the user, having prepared the SDK root dir with correct user ownership.
# If chown failed or was not complete, this step might fail.
echo "Installing SDK packages using sdkmanager..."

# Ensure the SDK directory and its contents are writable by the current user if we used sudo to create it.
# This is crucial for sdkmanager to work without sudo itself.
if [[ "${ANDROID_SDK_ROOT}" == /opt/* ]] && command -v sudo &> /dev/null; then
    echo "Ensuring current user has write permissions to ${ANDROID_SDK_ROOT} for sdkmanager..."
    sudo chown -R "$(whoami):$(whoami)" "${ANDROID_SDK_ROOT}" || echo "Warning: Failed to chown ${ANDROID_SDK_ROOT} for the current user. sdkmanager might fail."
fi

# Accept licenses automatically.
if command -v yes &> /dev/null; then
    yes | sdkmanager --licenses > /dev/null || echo "Warning: sdkmanager --licenses command finished with a non-zero exit code. This might be okay if licenses were already accepted or if sdkmanager needs sudo."
else
    echo "Warning: 'yes' command not found. Attempting to run sdkmanager --licenses without it."
    sdkmanager --licenses || echo "Warning: sdkmanager --licenses command finished with a non-zero exit code."
fi

echo "Installing platform-tools, platforms;android-35, and build-tools;34.0.0..."
# Try running sdkmanager as current user first.
sdkmanager "platform-tools" "platforms;android-35" "build-tools;34.0.0" || {
    echo "sdkmanager failed. If this is a permission issue and ANDROID_SDK_ROOT is in a protected location like /opt, trying with sudo..."
    if command -v sudo &> /dev/null; then
        sudo env "PATH=$PATH" "JAVA_HOME=$JAVA_HOME" "ANDROID_HOME=$ANDROID_HOME" "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT" sdkmanager "platform-tools" "platforms;android-35" "build-tools;34.0.0"
    else
        echo "sudo not available, sdkmanager command failed and cannot retry with sudo."
        exit 1
    fi
}

echo "Verifying installed packages:"
sdkmanager --list_installed || {
    echo "sdkmanager --list_installed failed. Trying with sudo..."
    if command -v sudo &> /dev/null; then
        sudo env "PATH=$PATH" "JAVA_HOME=$JAVA_HOME" "ANDROID_HOME=$ANDROID_HOME" "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT" sdkmanager --list_installed
    else
        echo "sudo not available, sdkmanager --list_installed failed and cannot retry with sudo."
    fi
}

echo "Android SDK setup and package installation complete."

echo "Navigating to project root (/app)..."
# Explicitly change to the known project root directory in the sandbox
cd /app
echo "Current directory: $(pwd)"
echo "Listing contents (/app directory):"
ls -la

echo "Attempting Gradle build..."
# Grant execute permissions to gradlew, just in case
if [ -f "./gradlew" ]; then
  chmod +x ./gradlew
  echo "Made ./gradlew executable."
else
  echo "ERROR: gradlew script not found in $(pwd). Cannot proceed with build."
  exit 1
fi

# Run a lighter task to verify setup, e.g., preBuild for a specific flavor
# Using --stacktrace for more detailed error output if the build fails
echo "Running: ./gradlew :app:preGenericDebugBuild --stacktrace"
./gradlew :app:preGenericDebugBuild --stacktrace

echo "Gradle task finished."
