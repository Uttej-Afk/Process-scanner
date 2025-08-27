#!/bin/bash
# Secure Login Node Python & Java Process Monitor

LOG_FILE="/scratch/admins/uttej/login-monitor/logs/ProcessLog_$(date '+%y-%m-%d').log"
CSV_FILE="/scratch/admins/uttej/login-monitor/logs/ProcessCSV_$(date '+%y-%m-%d').csv"
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

# Initialize CSV with a new "Process_Type" column
if [ ! -s "$CSV_FILE" ]; then
    echo "Timestamp,User,PID,Process_Type,CPU_Percent,Memory_Percent,Duration,Short_Command" > "$CSV_FILE"
fi

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
    fi
    
    # If a monitored process type was found, log it
    if [[ -n "$process_type" ]]; then
        # Clean input for logging
        clean_cmd=$(echo "$full_cmd" | tr -cd '[:print:][:space:]' | tr -d '\r')
        
        # Log and CSV output
        echo "$timestamp - $process_type Process PID $pid (User: $user, CPU: $pcpu%, MEM: $pmem%, Duration: $etime, Cmd: $comm)" >> "$LOG_FILE"
        echo "$(escape_csv "$timestamp"),$(escape_csv "$user"),$(escape_csv "$pid"),$(escape_csv "$process_type"),$(escape_csv "$pcpu"),$(escape_csv "$pmem"),$(escape_csv "$etime"),$(escape_csv "$comm")" >> "$CSV_FILE"
        
        found_pids+=("$pid")
        echo "Detected $process_type PID: $pid"
    fi
done < <(ps -eo user:20,pid,pcpu,pmem,etime,comm,args --no-headers 2>/dev/null)

# Summary
total=${#found_pids[@]}
(( total > 0 )) && echo "Summary: Found $total monitored process(es). PIDs: ${found_pids[*]}" || echo "No monitored processes found."
echo "Logs: $LOG_FILE | CSV: $CSV_FILE"
