#!/bin/bash
# Secure Login Node Python, Java, & Cursor Process Monitor

LOG_FILE="/scratch/admins/uttej/login-monitor/logs/ProcessLog_$(date '+%y-%m-%d').log"
CSV_FILE="/scratch/admins/uttej/login-monitor/logs/ProcessCSV_$(date '+%y-%m-%d').csv"

# Extract hostname (everything before @)
HOSTNAME=$(hostname)
CLUSTER_NAME="${HOSTNAME%%@*}"

# --- ADD THIS SECTION ---
# Get 1, 5, and 15-minute load averages
read -r load1 load5 load15 < <(uptime | awk -F'[, ]+' '{print $(NF-2), $(NF-1), $NF}')
# --- END ADDITION ---

WHITELIST_USERS=("root" "slurm" "admin")
WHITELIST_PROCS=("bash" "zsh" "sshd" "vim" "nano" "squeue" "sinfo" "code-server" "slurmd" "agetty" "systemd")

# Check write permissions
touch "$LOG_FILE" "$CSV_FILE" 2>/dev/null || { echo "Error: Cannot write to log files" >&2; exit 1; }

# Escape CSV fields containing special characters
escape_csv() { [[ "$1" =~ [,\"$'\n'] ]] && echo "\"${1//\"/\"\"}\"" || echo "$1"; }

# Build whitelist regex
build_regex() { local IFS='|'; echo "^(${*})$"; }
USER_REGEX=$(build_regex "${WHITELIST_USERS[@]}")
PROC_REGEX=$(build_regex "${WHITELIST_PROCS[@]}")

found_pids=()
timestamp=$(date '+%Y-%m-%d %H:%M:%S')

# Initialize CSV with a "Process_Type" column if it's a new file
# --- MODIFIED THIS IF BLOCK ---
if [ ! -s "$CSV_FILE" ]; then
    echo "Timestamp,Hostname,Load_Avg_1m,Load_Avg_5m,Load_Avg_15m,User,PID,Process_Type,CPU_Percent,Memory_Percent,Duration,Short_Command" > "$CSV_FILE"
fi
# --- END MODIFICATION ---

# Process monitoring loop
while read -r user pid pcpu pmem etime comm args; do
    [[ -z "$user" || -z "$pid" ]] && continue
    
    # Skip whitelisted users/processes
    echo "$user" | grep -qiE "$USER_REGEX" && continue
    echo "$comm" | grep -qiE "$PROC_REGEX" && continue
    
    full_cmd="$comm $args"
    process_type=""
    
    # Detect process type
    if echo "$full_cmd" | grep -qiE '(python|py3|\.py)([[:space:]]|$)'; then
        process_type="Python"
    elif echo "$full_cmd" | grep -qiE '(java|\.jar)([[:space:]]|$)'; then
        process_type="Java"
    elif echo "$full_cmd" | grep -qiE '(cursor)([[:space:]]|$)'; then
        process_type="Cursor"
    fi
    
    # If a monitored process type was found, log it
    if [[ -n "$process_type" ]]; then
        # Clean input for logging
        clean_cmd=$(echo "$full_cmd" | tr -cd '[:print:][:space:]' | tr -d '\r')
        
        # Log and CSV output
        echo "$timestamp - $process_type Process PID $pid (User: $user, CPU: $pcpu%, MEM: $pmem%, Duration: $etime, Cmd: $comm)" >> "$LOG_FILE"
        
        # --- MODIFIED THIS LINE ---
        echo "$(escape_csv "$timestamp"),$(escape_csv "$CLUSTER_NAME"),$(escape_csv "$load1"),$(escape_csv "$load5"),$(escape_csv "$load15"),$(escape_csv "$user"),$(escape_csv "$pid"),$(escape_csv "$process_type"),$(escape_csv "$pcpu"),$(escape_csv "$pmem"),$(escape_csv "$etime"),$(escape_csv "$comm")" >> "$CSV_FILE"
        # --- END MODIFICATION ---
        
        found_pids+=("$pid")
        echo "Detected $process_type PID: $pid"
    fi
done < <(ps -eo user:20,pid,pcpu,pmem,etime,comm,args --no-headers 2>/dev/null)

# Summary
total=${#found_pids[@]}
(( total > 0 )) && echo "Summary: Found $total monitored process(es). PIDs: ${found_pids[*]}" || echo "No monitored processes found."
echo "Logs: $LOG_FILE | CSV: $CSV_FILE"
