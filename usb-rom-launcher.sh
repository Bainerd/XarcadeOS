#!/bin/bash

# USB ROM Launcher - Enhanced with Colored Output and Fixed Logging

# Define color codes
RED='\033[0;31m'       # Red
GREEN='\033[0;32m'     # Green
YELLOW='\033[1;33m'    # Yellow
BLUE='\033[1;34m'      # Blue
NC='\033[0m'           # No Color

# Log file path
LOG_FILE="$HOME/usb-rom-launcher.log"

# Function to log messages to the log file with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Countdown function
countdown() {
    local seconds=$1
    while [[ $seconds -gt 0 ]]; do
        log "Launching Game, press Ctrl+C to quit... $seconds seconds remaining..."
        echo -ne "${YELLOW}Launching Game, press Ctrl+C to quit... $seconds seconds remaining...${NC}\r"
        sleep 1
        ((seconds--))
    done
    echo -ne "\n" # Clear the line
}

# Check for required commands
required_cmds=("lsblk" "grep" "awk" "find" "mame" "udisksctl")
missing_cmds=()
for cmd in "${required_cmds[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
   fi
done

if [[ ${#missing_cmds[@]} -ne 0 ]]; then
    for cmd in "${missing_cmds[@]}"; do
        log "Error: Required command '$cmd' is not installed. Please install it and retry."
        echo -e "${RED}Error: Required command '$cmd' is not installed. Please install it and retry.${NC}"
    done
    exit 1
fi

# Initialize log file
echo "----------------------------------------" >> "$LOG_FILE"
echo "USB ROM Launcher Log - $(date)" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"

log "USB ROM Launcher - Starting up..."
echo -e "${GREEN}USB ROM Launcher - Starting up...${NC}"
log "Log file: $LOG_FILE"
echo -e "${GREEN}Log file: $LOG_FILE${NC}"
echo ""

# Wait 10 seconds to ensure USB drive is connected
countdown 10

# List all block devices for debugging
log "Listing all block devices:"
echo -e "${BLUE}Listing all block devices:${NC}"
lsblk -lnp -o NAME,TRAN,MOUNTPOINT
log ""
echo ""

# Detect all USB devices
log "Detecting USB devices..."
echo -e "${BLUE}Detecting USB devices...${NC}"
usb_devices=($(lsblk -lnp -o NAME,TRAN | grep 'usb' | awk '{print $1}'))

if [[ ${#usb_devices[@]} -eq 0 ]]; then
    log "No USB devices detected. Exiting."
    echo -e "${RED}No USB devices detected. Exiting.${NC}"
    [[ $- == *i* ]] && read -p "Press Enter to close the terminal."
    exit 1
fi

for usb_device in "${usb_devices[@]}"; do
    log "Processing USB device: $usb_device"
    echo -e "${BLUE}Processing USB device: $usb_device${NC}"

    # Detect partitions on USB device
    log "Detecting partitions on USB device..."
    echo -e "${BLUE}Detecting partitions on USB device...${NC}"
    usb_partitions=($(lsblk -lnp -o NAME "$usb_device" | grep -E "${usb_device}[0-9]+$"))

    if [[ ${#usb_partitions[@]} -eq 0 ]]; then
        log "No partitions found on device: $usb_device. Skipping."
        echo -e "${YELLOW}No partitions found on device: $usb_device. Skipping.${NC}"
        continue
    fi

    for usb_partition in "${usb_partitions[@]}"; do
        log "USB partition detected: $usb_partition"
        echo -e "${GREEN}USB partition detected: $usb_partition${NC}"

        # Check if the USB partition is mounted
        log "Checking if the USB partition is mounted..."
        echo -e "${BLUE}Checking if the USB partition is mounted...${NC}"
        mount_point=$(lsblk -lnp -o MOUNTPOINT "$usb_partition")

        if [[ -z "$mount_point" ]]; then
            log "USB partition found but not mounted. Attempting to mount..."
            echo -e "${YELLOW}USB partition found but not mounted. Attempting to mount...${NC}"
            mount_output=$(udisksctl mount -b "$usb_partition" 2>&1)
            if [[ $? -ne 0 ]]; then
                log "Failed to mount the USB partition: $mount_output. Skipping."
                echo -e "${RED}Failed to mount the USB partition. Skipping.${NC}"
                continue
            else
                # Extract mount point from udisksctl output
                mount_point=$(echo "$mount_output" | grep -oP '(?<=at ).*')
                log "USB partition mounted at: $mount_point"
                echo -e "${GREEN}USB partition mounted at: $mount_point${NC}"
            fi
        else
            log "USB partition is already mounted at: $mount_point"
            echo -e "${GREEN}USB partition is already mounted at: $mount_point${NC}"
        fi

        if [[ -z "$mount_point" ]]; then
            log "Failed to detect a valid mount point for the USB partition. Exiting."
            echo -e "${RED}Failed to detect a valid mount point for the USB partition. Exiting.${NC}"
            [[ $- == *i* ]] && read -p "Press Enter to close the terminal."
            exit 1
        fi

        # Search for .zip files on the USB partition
        log "Searching for .zip files on the USB partition..."
        echo -e "${BLUE}Searching for .zip files on the USB partition...${NC}"
        mapfile -t zip_files < <(find "$mount_point" -maxdepth 1 -type f \( -iname "*.zip" -o -iname "*.ZIP" \))

        if [[ ${#zip_files[@]} -eq 0 ]]; then
            log "No .zip files detected on USB partition: $mount_point. Skipping."
            echo -e "${RED}No .zip files detected on USB partition: $mount_point. Skipping.${NC}"
            continue
        else
            log "Found the following .zip files on the USB partition:"
            echo -e "${GREEN}Found the following .zip files on the USB partition:${NC}"
            for file in "${zip_files[@]}"; do
                log " - $(basename "$file")"
                echo -e " - $(basename "$file")"
            done
            log ""
            echo ""
        fi

        # Locate MAME
        mame_cmd=$(command -v mame)
        log "MAME command path: '$mame_cmd'"
        echo -e "${BLUE}MAME command path: '$mame_cmd'${NC}"

        if [[ -z "$mame_cmd" ]]; then
            log "MAME not found. Please install MAME and ensure it's in your PATH."
            echo -e "${RED}MAME not found. Please install MAME and ensure it's in your PATH.${NC}"
            [[ $- == *i* ]] && read -p "Press Enter to close the terminal."
            exit 1
        fi

        # Iterate safely over zip files
        for romfile in "${zip_files[@]}"; do
            romname=$(basename "$romfile")
            log "Preparing to run game: $romname"
            echo -e "${BLUE}Preparing to run game: $romname${NC}"

            # Extract system name from the .zip file (strip extension)
            system="${romname%.*}"

            log "Launching $system directly from USB: $romfile"
            echo -e "${GREEN}Launching $system directly from USB: $romfile${NC}"
            "$mame_cmd" "$system" -rompath "$mount_point" &> /tmp/mame_output.log
            mame_exit_code=$?

            if [[ $mame_exit_code -eq 0 ]]; then
                log "Game '$system' launched successfully!"
                echo -e "${GREEN}Game '$system' launched successfully!${NC}"
            else
                log "Game '$system' failed to launch. Checking MAME output..."
                echo -e "${RED}Game '$system' failed to launch. Checking MAME output...${NC}"
                echo "-----------------------------"
                cat /tmp/mame_output.log
                echo "-----------------------------"
                log "Please review the above log for details."
                echo -e "${YELLOW}Please review the above log for details.${NC}"
            fi
        done

        # Unmount the USB partition after processing
        log "Unmounting USB partition: $mount_point"
        echo -e "${BLUE}Unmounting USB partition: $mount_point${NC}"
        unmount_output=$(udisksctl unmount -b "$usb_partition" 2>&1)
        if [[ $? -ne 0 ]]; then
            log "Failed to unmount USB partition: $unmount_output"
            echo -e "${RED}Failed to unmount USB partition: $unmount_output${NC}"
        else
            log "USB partition unmounted successfully."
            echo -e "${GREEN}USB partition unmounted successfully.${NC}"
        fi
    done
done

log ""
log "USB ROM Launcher - Completed."
echo -e "${GREEN}USB ROM Launcher - Completed.${NC}"
[[ $- == *i* ]] && read -p "Press Enter to close the terminal."
