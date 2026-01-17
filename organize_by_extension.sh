#!/bin/bash

# File Organization Script with Advanced Features
# Usage: ./organize_by_extension.sh [PATH] [IGNORE_FOLDERS]
# Example: ./organize_by_extension.sh ~/Downloads "temp,backup,archive"

# =============================================================================
# CONFIGURATION SECTION - Modify these as needed
# =============================================================================

# File types to process (leave empty to process all extensions)
INCLUDE_EXTENSIONS=""  # Example: "jpg,png,pdf,mp4" or leave empty for all

# File types to ignore completely
EXCLUDE_EXTENSIONS="tmp,temp,log,bak"  # Add extensions to ignore

# File size range (in bytes) - set to 0 to ignore size limits
MIN_FILE_SIZE=0        # Minimum file size (0 = no limit)
MAX_FILE_SIZE=0        # Maximum file size (0 = no limit)

# Folder naming with timestamp
USE_TIMESTAMP=false    # Set to true to add timestamp like Extension_JPG_20250117
DATE_FORMAT="%Y%m%d"   # Date format for folder names

# Default folders to ignore (case-insensitive)
DEFAULT_IGNORE_FOLDERS="logs,cache,temp"

# =============================================================================
# SCRIPT VARIABLES
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/organize_log_$(date +%Y%m%d_%H%M%S).log"
ERROR_DIR=""
TIMESTAMP=$(date +"$DATE_FORMAT")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# FUNCTIONS
# =============================================================================

print_usage() {
    echo "Usage: $0 [PATH] [IGNORE_FOLDERS]"
    echo ""
    echo "Parameters:"
    echo "  PATH            Directory to organize (default: current directory)"
    echo "  IGNORE_FOLDERS  Comma-separated list of folders to ignore"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Organize current directory"
    echo "  $0 ~/Downloads                       # Organize Downloads folder"
    echo "  $0 ~/Downloads \"temp,backup,old\"     # Ignore specific folders"
    echo ""
    echo "Configuration (edit script to modify):"
    echo "  INCLUDE_EXTENSIONS: '$INCLUDE_EXTENSIONS'"
    echo "  EXCLUDE_EXTENSIONS: '$EXCLUDE_EXTENSIONS'"
    echo "  MIN_FILE_SIZE: $MIN_FILE_SIZE bytes"
    echo "  MAX_FILE_SIZE: $MAX_FILE_SIZE bytes"
    echo "  USE_TIMESTAMP: $USE_TIMESTAMP"
}

log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
}

print_colored() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

is_ignored_folder() {
    local folder="$1"
    local ignore_list="$2"
    
    # Convert to lowercase for case-insensitive comparison
    folder_lower=$(echo "$folder" | tr '[:upper:]' '[:lower:]')
    ignore_lower=$(echo "$ignore_list" | tr '[:upper:]' '[:lower:]')
    
    IFS=',' read -ra IGNORE_ARRAY <<< "$ignore_lower"
    for ignore_item in "${IGNORE_ARRAY[@]}"; do
        ignore_item=$(echo "$ignore_item" | xargs) # trim whitespace
        if [[ "$folder_lower" == "$ignore_item" ]]; then
            return 0
        fi
    done
    return 1
}

is_valid_extension() {
    local ext="$1"
    
    # Check if extension is in exclude list
    if [[ -n "$EXCLUDE_EXTENSIONS" ]]; then
        IFS=',' read -ra EXCLUDE_ARRAY <<< "${EXCLUDE_EXTENSIONS,,}"
        for exclude_ext in "${EXCLUDE_ARRAY[@]}"; do
            exclude_ext=$(echo "$exclude_ext" | xargs)
            if [[ "${ext,,}" == "$exclude_ext" ]]; then
                return 1
            fi
        done
    fi
    
    # Check if extension is in include list (if specified)
    if [[ -n "$INCLUDE_EXTENSIONS" ]]; then
        IFS=',' read -ra INCLUDE_ARRAY <<< "${INCLUDE_EXTENSIONS,,}"
        for include_ext in "${INCLUDE_ARRAY[@]}"; do
            include_ext=$(echo "$include_ext" | xargs)
            if [[ "${ext,,}" == "$include_ext" ]]; then
                return 0
            fi
        done
        return 1
    fi
    
    return 0
}

is_valid_size() {
    local file_size="$1"
    
    if [[ $MIN_FILE_SIZE -gt 0 && $file_size -lt $MIN_FILE_SIZE ]]; then
        return 1
    fi
    
    if [[ $MAX_FILE_SIZE -gt 0 && $file_size -gt $MAX_FILE_SIZE ]]; then
        return 1
    fi
    
    return 0
}

move_to_error() {
    local file="$1"
    local reason="$2"
    
    if [[ -z "$ERROR_DIR" ]]; then
        ERROR_DIR="$ROOT_DIR/Extension_ERROR"  # ✨ CHANGED
        mkdir -p "$ERROR_DIR"
    fi
    
    local filename=$(basename "$file")
    local error_file="$ERROR_DIR/$filename"
    
    # Handle naming conflicts in error directory
    local count=1
    while [[ -e "$error_file" ]]; do
        local base="${filename%.*}"
        local ext="${filename##*.}"
        if [[ "$ext" == "$filename" ]]; then
            error_file="$ERROR_DIR/${filename}_$count"
        else
            error_file="$ERROR_DIR/${base}_$count.$ext"
        fi
        ((count++))
    done
    
    mv "$file" "$error_file"
    print_colored "$RED" "❌ Error ($reason): $file → $error_file"
    log_message "ERROR: $reason - moved $file to $error_file"
}

get_folder_name() {
    local ext="$1"
    if [[ "$USE_TIMESTAMP" == "true" ]]; then
        echo "Extension_${ext}_${TIMESTAMP}"  # ✨ CHANGED
    else
        echo "Extension_${ext}"  # ✨ CHANGED
    fi
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

# Parse arguments
ROOT_DIR="${1:-.}"
IGNORE_FOLDERS="${2:-$DEFAULT_IGNORE_FOLDERS}"

# Show help if requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    print_usage
    exit 0
fi

# Validate directory
if [[ ! -d "$ROOT_DIR" ]]; then
    print_colored "$RED" "❌ Directory not found: $ROOT_DIR"
    exit 1
fi

# Convert to absolute path
ROOT_DIR=$(cd "$ROOT_DIR" && pwd)

# Initialize log
log_message "=== File Organization Started ==="
log_message "Root directory: $ROOT_DIR"
log_message "Ignore folders: $IGNORE_FOLDERS"
log_message "Include extensions: ${INCLUDE_EXTENSIONS:-ALL}"
log_message "Exclude extensions: $EXCLUDE_EXTENSIONS"
log_message "Min file size: $MIN_FILE_SIZE bytes"
log_message "Max file size: $MAX_FILE_SIZE bytes"

print_colored "$BLUE" "📂 Organizing files in: $ROOT_DIR"
print_colored "$CYAN" "📝 Log file: $LOG_FILE"
print_colored "$YELLOW" "⚙️  Configuration:"
echo "   • Include extensions: ${INCLUDE_EXTENSIONS:-ALL}"
echo "   • Exclude extensions: $EXCLUDE_EXTENSIONS"
echo "   • Size range: $MIN_FILE_SIZE - $MAX_FILE_SIZE bytes"
echo "   • Ignore folders: $IGNORE_FOLDERS"
echo "   • Use timestamp: $USE_TIMESTAMP"
echo ""

# Statistics
total_files=0
moved_files=0
removed_files=0
error_files=0

# Process files
while IFS= read -r -d '' file; do
    ((total_files++))
    
    # Skip hidden files
    filename=$(basename "$file")
    if [[ "$filename" == .* ]]; then
        continue
    fi
    
    # Check if file is in ignored folder
    rel_path="${file#$ROOT_DIR/}"
    top_folder="${rel_path%%/*}"
    
    if is_ignored_folder "$top_folder" "$IGNORE_FOLDERS"; then
        continue
    fi
    
    # ✨ FIXED: Skip files already in Extension_ folders
    if [[ "$top_folder" =~ ^Extension_ ]]; then
        continue
    fi
    
    # Extract extension
    base="${filename%.*}"
    ext="${filename##*.}"
    
    # Skip files without extension
    if [[ "$ext" == "$filename" ]]; then
        move_to_error "$file" "No extension"
        ((error_files++))
        continue
    fi
    
    # Validate extension
    if ! is_valid_extension "$ext"; then
        move_to_error "$file" "Excluded extension: $ext"
        ((error_files++))
        continue
    fi
    
    # Check file size
    if ! file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null); then
        move_to_error "$file" "Cannot read file size"
        ((error_files++))
        continue
    fi
    
    if ! is_valid_size "$file_size"; then
        move_to_error "$file" "File size out of range: $file_size bytes"
        ((error_files++))
        continue
    fi
    
    # Get file hash
    if ! file_hash=$(shasum "$file" 2>/dev/null | awk '{print $1}'); then
        move_to_error "$file" "Cannot calculate hash"
        ((error_files++))
        continue
    fi
    
    # Process file
    ext_upper="${ext^^}"
    folder_name=$(get_folder_name "$ext_upper")
    dest_dir="$ROOT_DIR/$folder_name"
    dest_file="$dest_dir/$filename"
    existing_dir="$ROOT_DIR/Extension_EXISTING/$folder_name"  # ✨ CHANGED
    
    # Create destination directory
    mkdir -p "$dest_dir"
    
    if [[ ! -e "$dest_file" ]]; then
        # Case 1: No conflict, move normally
        if mv "$file" "$dest_file"; then
            print_colored "$GREEN" "✅ Moved: $file → $dest_file"
            log_message "MOVED: $file → $dest_file"
            ((moved_files++))
        else
            move_to_error "$file" "Failed to move file"
            ((error_files++))
        fi
    else
        # File with same name exists, check size and content
        if ! existing_size=$(stat -f%z "$dest_file" 2>/dev/null || stat -c%s "$dest_file" 2>/dev/null); then
            move_to_error "$file" "Cannot read existing file size"
            ((error_files++))
            continue
        fi
        
        if ! existing_hash=$(shasum "$dest_file" 2>/dev/null | awk '{print $1}'); then
            move_to_error "$file" "Cannot calculate existing file hash"
            ((error_files++))
            continue
        fi
        
        if [[ "$file_size" != "$existing_size" ]]; then
            # Case 2: Same name, different size - rename and move to type folder
            count=1
            while [[ -e "$dest_dir/${base}_$count.$ext" ]]; do
                ((count++))
            done
            new_name="${base}_$count.$ext"
            if mv "$file" "$dest_dir/$new_name"; then
                print_colored "$YELLOW" "📁 Different size - renamed: $file → $dest_dir/$new_name"
                log_message "RENAMED: Different size - $file → $dest_dir/$new_name"
                ((moved_files++))
            else
                move_to_error "$file" "Failed to rename and move"
                ((error_files++))
            fi
        elif [[ "$file_hash" == "$existing_hash" ]]; then
            # Case 3: Same name, same size, same content - remove duplicate
            if rm "$file"; then
                print_colored "$PURPLE" "🗑️  Duplicate removed: $file"
                log_message "REMOVED: Exact duplicate - $file"
                ((removed_files++))
            else
                move_to_error "$file" "Failed to remove duplicate"
                ((error_files++))
            fi
        else
            # Case 4: Same name, same size, different content - move to Extension_EXISTING
            mkdir -p "$existing_dir"
            existing_dest="$existing_dir/$filename"
            
            if [[ ! -e "$existing_dest" ]]; then
                # First conflict file goes to Extension_EXISTING with original name
                if mv "$file" "$existing_dest"; then
                    print_colored "$CYAN" "🔄 Different content - moved to Extension_EXISTING: $file → $existing_dest"
                    log_message "EXISTING: Different content - $file → $existing_dest"
                    ((moved_files++))
                else
                    move_to_error "$file" "Failed to move to Extension_EXISTING"
                    ((error_files++))
                fi
            else
                # Additional conflicts get numbered in Extension_EXISTING
                count=1
                duplicate_found=false
                
                while [[ -e "$existing_dir/${base}_$count.$ext" ]]; do
                    if existing_conflict_hash=$(shasum "$existing_dir/${base}_$count.$ext" 2>/dev/null | awk '{print $1}'); then
                        if [[ "$file_hash" == "$existing_conflict_hash" ]]; then
                            rm "$file"
                            print_colored "$PURPLE" "🗑️  Duplicate in Extension_EXISTING - removed: $file"
                            log_message "REMOVED: Duplicate in Extension_EXISTING - $file"
                            ((removed_files++))
                            duplicate_found=true
                            break
                        fi
                    fi
                    ((count++))
                done
                
                # If file wasn't removed as duplicate, move it with new number
                if [[ "$duplicate_found" == false && -e "$file" ]]; then
                    new_existing_name="${base}_$count.$ext"
                    if mv "$file" "$existing_dir/$new_existing_name"; then
                        print_colored "$CYAN" "🔄 Different content - moved to Extension_EXISTING: $file → $existing_dir/$new_existing_name"
                        log_message "EXISTING: Different content - $file → $existing_dir/$new_existing_name"
                        ((moved_files++))
                    else
                        move_to_error "$file" "Failed to move to Extension_EXISTING with new name"
                        ((error_files++))
                    fi
                fi
            fi
        fi
    fi
    
done < <(find "$ROOT_DIR" -type f -print0)

# Final summary
log_message "=== File Organization Completed ==="
log_message "Total files processed: $total_files"
log_message "Files moved: $moved_files"
log_message "Duplicates removed: $removed_files"
log_message "Files with errors: $error_files"

echo ""
print_colored "$GREEN" "🎉 Organization completed!"
echo "📊 Summary:"
echo "   • Total files processed: $total_files"
echo "   • Files moved: $moved_files"
echo "   • Duplicates removed: $removed_files"
echo "   • Files with errors: $error_files"
echo ""
print_colored "$CYAN" "📝 Detailed log saved to: $LOG_FILE"

if [[ $error_files -gt 0 ]]; then
    print_colored "$YELLOW" "⚠️  $error_files files moved to Extension_ERROR folder due to issues"
fi

Extension_ERROR/
