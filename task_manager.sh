#!/bin/bash

# Global Variables
LOG_FILE="task_scheduler.log"
TASK_FILE="tasks.txt"
WORKFLOW_FILE="workflows.txt"  # File to store workflows
EMAIL="your-email@example.com"  # Replace with your actual email

# Log function
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
    echo "$message"
}

# Send email notification
send_email() {
    local subject="$1"
    local body="$2"
    echo "$body" | mailx -s "$subject" "$EMAIL"
    log_message "Notification sent: $subject"
}

# Define a task
define_task() {
    echo "Enter task name:"
    read -r task_name
    echo "Enter command to execute (absolute paths required):"
    read -r command
    echo "Enter schedule (cron format):"
    read -r schedule
    echo "$task_name|$command|$schedule" >> "$TASK_FILE"
    log_message "Task defined: $task_name"
    echo "Task defined successfully."
}

# Define a workflow
define_workflow() {
    echo "Enter workflow name:"
    read -r workflow_name
    echo "Enter tasks in order (comma-separated):"
    read -r tasks
    echo "$workflow_name|$tasks" >> "$WORKFLOW_FILE"
    log_message "Workflow defined: $workflow_name"
    echo "Workflow defined successfully."
}
#Exectues workflow
execute_workflow() {
    echo "Enter workflow name to execute:"
    read -r workflow_name
    local workflow=$(grep "^$workflow_name|" "$WORKFLOW_FILE")
    if [[ -z "$workflow" ]]; then
        echo "Workflow not found."
        return
    fi
    local tasks=$(echo "$workflow" | cut -d'|' -f2)
    IFS=',' read -ra task_list <<< "$tasks"
    for task_name in "${task_list[@]}"; do
        local task=$(grep "^$task_name|" "$TASK_FILE")
        if [[ -n "$task" ]]; then
            local command=$(echo "$task" | cut -d'|' -f2)
            log_message "Executing task: $task_name"
            echo "Found task: $task_name with command: $command"  # Debug statement
            eval "$command"
            if [[ $? -eq 0 ]]; then
                log_message "Task $task_name completed successfully."
                send_email "Task Completed: $task_name" "Task $task_name has been completed successfully."
            else
                log_message "Task $task_name failed."
                send_email "Task Failed: $task_name" "Task $task_name failed to execute."
                return 1
            fi
        else
            log_message "Task $task_name not found in workflow $workflow_name."
            echo "Task $task_name not found in tasks.txt."  # Debug statement
            send_email "Task Not Found: $task_name" "Task $task_name is missing in the workflow $workflow_name."
            return 1
        fi
    done
    log_message "Workflow $workflow_name completed successfully."
    send_email "Workflow Completed: $workflow_name" "Workflow $workflow_name has been completed successfully."
}

# Install tasks into crontab
install_cron_jobs() {
    crontab -l > temp_cron 2>/dev/null
    while IFS= read -r line; do
        local task_name=$(echo "$line" | cut -d'|' -f1)
        local command=$(echo "$line" | cut -d'|' -f2)
        local schedule=$(echo "$line" | cut -d'|' -f3)
        echo "$schedule $command >> $LOG_FILE 2>&1" >> temp_cron
        log_message "Scheduled task: $task_name ($schedule)"
    done < "$TASK_FILE"
    crontab temp_cron
    rm temp_cron
    log_message "All tasks installed in crontab."
    echo "Tasks have been scheduled."
}

# View logs
view_logs() {
    echo "Displaying log file contents:"
    if [[ -f $LOG_FILE ]]; then
        cat "$LOG_FILE"
    else
        echo "No logs available yet."
    fi
}

# Menu
while true; do
    echo "Task Scheduler Menu"
    echo "1. Define a Task"
    echo "2. Define a Workflow"
    echo "3. Execute a Workflow"
    echo "4. Schedule Tasks in Crontab"
    echo "5. View Logs"
    echo "6. Exit"
    read -r choice

    case $choice in
        1) define_task ;;
        2) define_workflow ;;
        3) execute_workflow ;;
        4) install_cron_jobs ;;
        5) view_logs ;;
        6) echo "Exiting task scheduler."; break ;;
        *) echo "Invalid choice. Please try again." ;;
    esac
done

