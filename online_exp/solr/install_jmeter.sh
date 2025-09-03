#!/bin/bash
# install_jmeter.sh
# This script installs Apache JMeter if it is not already installed in /opt.
# It is adapted for users of the Zsh shell.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
JMETER_VERSION="5.6.3"
INSTALL_DIR="/opt"
JMETER_HOME_SYMLINK="${INSTALL_DIR}/jmeter"
JMETER_FULL_DIR="${INSTALL_DIR}/apache-jmeter-${JMETER_VERSION}"

# --- Check if JMeter is already installed ---
if [ -d "${JMETER_HOME_SYMLINK}" ]; then
    echo "JMeter appears to be already installed at ${JMETER_HOME_SYMLINK}."
    echo "Installation skipped."
    exit 0
fi

# --- Start Installation ---
echo "=== Installing JMeter ${JMETER_VERSION} ==="

# Check for write permissions to /opt
if [ ! -w "${INSTALL_DIR}" ]; then
    echo "Error: You don't have write permissions for ${INSTALL_DIR}."
    echo "Please run this script with sudo, e.g., 'sudo ./install_jmeter.sh'"
    exit 1
fi

# Switch to the installation directory
cd "${INSTALL_DIR}"

# Download
echo "Downloading JMeter..."
wget "https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-${JMETER_VERSION}.tgz"

# Extract
echo "Extracting..."
tar -xzf "apache-jmeter-${JMETER_VERSION}.tgz"

# Create a convenient symlink
echo "Creating symlink..."
ln -sf "${JMETER_FULL_DIR}" "${JMETER_HOME_SYMLINK}"

# Clean up the downloaded archive
echo "Cleaning up..."
rm "apache-jmeter-${JMETER_VERSION}.tgz"

# --- Set environment variables for the current user in .zshrc ---
echo "Setting environment variables for Zsh..."
# Add a newline for better formatting in .zshrc, if the file doesn't end with one
echo "" >> ~/.zshrc
echo "# Apache JMeter Environment Variables" >> ~/.zshrc
echo "export JMETER_HOME=${JMETER_HOME_SYMLINK}" >> ~/.zshrc
echo 'export PATH=$PATH:$JMETER_HOME/bin' >> ~/.zshrc

# --- Apply environment variables for the current session ---
export JMETER_HOME=${JMETER_HOME_SYMLINK}
export PATH=$PATH:$JMETER_HOME/bin

# --- Verify Installation ---
echo "Verifying installation..."
# Use the new PATH to call jmeter directly
jmeter -v

echo
echo "=== JMeter installed successfully at ${JMETER_HOME_SYMLINK} ==="
echo "Environment variables have been added to your ~/.zshrc file."
echo "Please run 'source ~/.zshrc' or open a new terminal to use the 'jmeter' command."

source ~/.zshrc