#!/bin/bash
# Secure Login Node Python Process Monitor


LOG_FILE="/var/tmp/ProcessLog_$(date '+%y-%m-%d').log"
CSV_FILE="/var/tmp/ProcessCSV_$(date '+%y-%m-%d').csv"
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

# Initialize CSV
echo "Timestamp,User,PID,CPU_Percent,Memory_Percent,Duration,Short_Command" > "$CSV_FILE"

# Process monitoring loop
while read -r user pid pcpu pmem etime comm args; do
    [[ -z "$user" || -z "$pid" ]] && continue
    
    # Skip whitelisted users/processes
    echo "$user" | grep -qiE "$USER_REGEX" && continue
    echo "$comm" | grep -qiE "$PROC_REGEX" && continue
    
    # Detect Python processes
    if echo "$comm $args" | grep -qiE '(python|py3|\.py)([[:space:]]|$)'; then
        # Clean input for logging
        clean_cmd=$(echo "$comm $args" | tr -cd '[:print:][:space:]' | tr -d '\r')
        
        # Log and CSV output
        echo "$timestamp - Python Process PID $pid (User: $user, CPU: $pcpu%, MEM: $pmem%, Duration: $etime, Cmd: $comm)" >> "$LOG_FILE"
        echo "$(escape_csv "$timestamp"),$(escape_csv "$user"),$(escape_csv "$pid"),$(escape_csv "$pcpu"),$(escape_csv "$pmem"),$(escape_csv "$etime"),$(escape_csv "$comm")" >> "$CSV_FILE"
        
        found_pids+=("$pid")
        echo "Detected Python PID: $pid"
    fi
done < <(ps -eo user:20,pid,pcpu,pmem,etime,comm,args --no-headers 2>/dev/null)

# Summary
total=${#found_pids[@]}
(( total > 0 )) && echo "Summary: Found $total Python process(es). PIDs: ${found_pids[*]}" || echo "No Python processes found."
echo "Logs: $LOG_FILE | CSV: $CSV_FILE"
