#!/bin/bash
#
# log_load_average.sh
# A lightweight script to capture system load average and log it to a daily CSV file.
#

# --- Configuration ---
# Set the directory where you want to store the CSV logs.
LOG_DIR="/scratch/admins/uttej/login_monitor/logs"

# --- Script Body (No need to edit below this line) ---

# Ensure the log directory exists.
mkdir -p "$LOG_DIR"

# Set the CSV filename based on the current date.
CSV_FILE="${LOG_DIR}/load_avg_log_$(date +'%y-%m-%d').csv"

# Get the current timestamp.
timestamp=$(date '+%Y-%m-%d %H:%M:%S')

# Get the short hostname of the machine.
hostname=$(hostname -s)

# Get the 1, 5, and 15-minute load averages.
read -r load1 load5 load15 < <(uptime | awk -F'[, ]+' '{print $(NF-2), $(NF-1), $NF}')

# Create the CSV file with a header row if it doesn't already exist.
if [ ! -f "$CSV_FILE" ]; then
    echo "Timestamp,Hostname,Load_Avg_1m,Load_Avg_5m,Load_Avg_15m" > "$CSV_FILE"
fi

# Append the current data as a new row to the CSV file.
echo "${timestamp},${hostname},${load1},${load5},${load15}" >> "$CSV_FILE"

# Optional: Print a confirmation message (will show up in cron logs).
echo "Load average for ${hostname} logged to ${CSV_FILE}"
