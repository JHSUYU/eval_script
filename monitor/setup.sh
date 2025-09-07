#!/bin/bash

# Setup script for distributed monitoring system
# Installs JVMTop on all configured servers

# Configuration
SERVERS=(
    "10.10.1.1"
    "10.10.1.2"
    "10.10.1.3"
    "10.10.1.4"
    "10.10.1.5"
)

SSH_USER="ZhenyuLi"
JVMTOP_VERSION="0.8.0"
JVMTOP_URL="https://github.com/patric-r/jvmtop/releases/download/${JVMTOP_VERSION}/jvmtop-${JVMTOP_VERSION}.tar.gz"

echo "========================================="
echo "Distributed Monitoring System Setup"
echo "========================================="
echo ""

# Function to install JVMTop on a single server
install_jvmtop_on_server() {
    local server=$1

    echo "Installing JVMTop on ${server}..."

    ssh ${SSH_USER}@${server} << EOF
        # Create jvmtop directory
        mkdir -p ~/jvmtop-${JVMTOP_VERSION}
        cd ~/jvmtop-${JVMTOP_VERSION}

        # Check if JVMTop is already installed
        if [ -f "jvmtop.sh" ] && [ -f "jvmtop.jar" ]; then
            echo "  JVMTop ${JVMTOP_VERSION} already installed"
        else
            echo "  Downloading JVMTop ${JVMTOP_VERSION}..."
            wget -q ${JVMTOP_URL} -O /tmp/jvmtop-${JVMTOP_VERSION}.tar.gz

            echo "  Extracting JVMTop..."
            tar -xzf /tmp/jvmtop-${JVMTOP_VERSION}.tar.gz
            rm /tmp/jvmtop-${JVMTOP_VERSION}.tar.gz

            echo "  Testing JVMTop installation..."
            chmod +x jvmtop.sh
            if ./jvmtop.sh --help > /dev/null 2>&1; then
                echo "  ✓ JVMTop installed successfully"
            else
                echo "  ✗ JVMTop installation failed"
                exit 1
            fi
        fi

        # Create monitoring directory and subdirectories
        mkdir -p ~/monitor/logs ~/monitor/processed
        echo "  ✓ Monitoring directories created"
EOF

    if [ $? -eq 0 ]; then
        echo "✓ Setup completed on ${server}"
    else
        echo "✗ Setup failed on ${server}"
        return 1
    fi
    echo ""
}

# Function to deploy monitor_tools.py to server
deploy_monitor_tools_to_server() {
    local server=$1

    echo "Deploying monitor_tools.py to ${server}..."

    # Copy the unified Python tool
    scp -q monitor_tools.py ${SSH_USER}@${server}:~/monitor/

    if [ $? -eq 0 ]; then
        # Make it executable
        ssh -q ${SSH_USER}@${server} "chmod +x ~/monitor/monitor_tools.py"
        echo "✓ monitor_tools.py deployed to ${server}"
    else
        echo "✗ Failed to deploy monitor_tools.py to ${server}"
        return 1
    fi
}

# Function to verify Python installation
verify_python_on_server() {
    local server=$1

    echo "Verifying Python 3 on ${server}..."

    python_version=$(ssh -q ${SSH_USER}@${server} "python3 --version 2>&1")

    if [[ $python_version == *"Python 3"* ]]; then
        echo "  ✓ ${python_version}"
        return 0
    else
        echo "  ✗ Python 3 not found"
        return 1
    fi
}

# Main setup process
main() {
    echo "Setting up monitoring on ${#SERVERS[@]} servers..."
    echo ""

    # Check if local monitor_tools.py exists
    if [ ! -f "monitor_tools.py" ]; then
        echo "Error: monitor_tools.py not found in current directory"
        echo "Please ensure monitor_tools.py is present"
        exit 1
    fi

    # Check if monitor.sh exists
    if [ ! -f "monitor.sh" ]; then
        echo "Warning: monitor.sh not found in current directory"
        echo "Make sure to have monitor.sh for running the monitoring"
    fi

    echo "Phase 1: Verifying Python 3 installation"
    echo "-----------------------------------------"
    python_failed=()
    for server in "${SERVERS[@]}"; do
        if ! verify_python_on_server "$server"; then
            python_failed+=("$server")
        fi
    done

    if [ ${#python_failed[@]} -gt 0 ]; then
        echo ""
        echo "⚠ Warning: Python 3 not found on these servers:"
        for server in "${python_failed[@]}"; do
            echo "  - ${server}"
        done
        echo "  Monitor tools may not work properly on these servers"
        echo ""
    fi

    echo ""
    echo "Phase 2: Installing JVMTop"
    echo "-----------------------------------------"
    install_failed=()
    for server in "${SERVERS[@]}"; do
        if ! install_jvmtop_on_server "$server"; then
            install_failed+=("$server")
        fi
    done

    echo ""
    echo "Phase 3: Deploying monitor_tools.py"
    echo "-----------------------------------------"
    deploy_failed=()
    for server in "${SERVERS[@]}"; do
        if ! deploy_monitor_tools_to_server "$server"; then
            deploy_failed+=("$server")
        fi
    done

    # Create local directories
    echo ""
    echo "Phase 4: Creating local directories"
    echo "-----------------------------------------"
    mkdir -p logs processed results reports
    echo "✓ Local directories created: logs/ processed/ results/ reports/"

    # Calculate total failures
    all_failed_servers=()
    for server in "${install_failed[@]}"; do
        all_failed_servers+=("$server")
    done
    for server in "${deploy_failed[@]}"; do
        if [[ ! " ${all_failed_servers[@]} " =~ " ${server} " ]]; then
            all_failed_servers+=("$server")
        fi
    done

    echo ""
    echo "========================================="
    echo "Setup Summary"
    echo "========================================="

    if [ ${#all_failed_servers[@]} -eq 0 ]; then
        echo "✓ All servers configured successfully!"
    else
        echo "✗ Setup encountered issues on the following servers:"
        for server in "${all_failed_servers[@]}"; do
            echo "  - ${server}"
            if [[ " ${install_failed[@]} " =~ " ${server} " ]]; then
                echo "    Issue: JVMTop installation failed"
            fi
            if [[ " ${deploy_failed[@]} " =~ " ${server} " ]]; then
                echo "    Issue: monitor_tools.py deployment failed"
            fi
        done
        echo ""
        echo "Partial setup completed. You can:"
        echo "1. Fix the issues and re-run setup.sh"
        echo "2. Proceed with monitoring on successful servers only"
        echo ""
        echo "To retry setup on failed servers, check:"
        echo "  - SSH connectivity: ssh ${SSH_USER}@<server>"
        echo "  - Internet access for downloading JVMTop"
        echo "  - Write permissions in home directory"
        exit 1
    fi
}

# Display help if requested
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Usage: ./setup.sh"
    echo ""
    echo "This script sets up the distributed monitoring system by:"
    echo "  1. Verifying Python 3 on all servers"
    echo "  2. Installing JVMTop on all servers"
    echo "  3. Deploying monitor_tools.py to all servers"
    echo "  4. Creating necessary directories"
    exit 0
fi

# Run main
main