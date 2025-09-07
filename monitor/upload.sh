#!/bin/bash

# Upload monitor folder to remote server
# Usage: ./upload.sh user@host

if [ $# -ne 1 ]; then
    echo "Usage: $0 <user@host>"
    echo "Example: $0 ZhenyuLi@ms1238.utah.cloudlab.us"
    exit 1
fi

REMOTE_TARGET=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_DIR="${SCRIPT_DIR}"

echo "Uploading monitor folder to ${REMOTE_TARGET}:~/"
scp -r "${MONITOR_DIR}" "${REMOTE_TARGET}:~/"

if [ $? -eq 0 ]; then
    echo "Upload successful!"
else
    echo "Upload failed!"
    exit 1
fi