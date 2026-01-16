# Quick One-Liner Command (for current folder)
# for f in *.*; do ext="${f##*.}"; mkdir -p "${ext^^}"; mv -- "$f" "${ext^^}/"; done

# 🔹 What this does:
# 	•	Loops over all files with an extension.
# 	•	Extracts the extension (e.g., jpg, pdf).
# 	•	Creates a folder with that extension name in UPPERCASE.
# 	•	Moves the file into that folder.
# Example: photo.jpg → JPG/photo.jpg
# ⚠️ Limitations:
# 	•	Only works in the current directory.
# 	•	Won’t recurse into subdirectories.
# 	•	Will overwrite files if duplicates exist (unless enhanced).
# ⸻

for f in *.*; do
  ext="${f##*.}"
  ext_upper="${(U)ext}"       # zsh way to uppercase
  mkdir -p "$ext_upper"
  mv -- "$f" "$ext_upper/"
done


# ⸻
# Better Script: organize_by_type.sh
#!/bin/bash
TARGET_DIR="${1:-$(pwd)}"
echo "📁 Organizing files in: $TARGET_DIR"
cd "$TARGET_DIR" || { echo "❌ Failed to access $TARGET_DIR"; exit 1; }
# Loop over all files (not folders)
find . -maxdepth 1 -type f | while read -r file; do
  # Extract extension in uppercase
  ext="${file##*.}"
  ext_upper=$(echo "$ext" | tr '[:lower:]' '[:upper:]')
  # Skip if no extension or hidden
  [[ "$file" == "$ext" || "$file" == .* ]] && continue
  # Create folder and move file
  mkdir -p "$ext_upper"
  mv -- "$file" "$ext_upper/" 2>/dev/null
done
echo "✅ Done organizing files by type."

# Save the script:nano organize_by_type.sh
# Make it executable: chmod +x organize_by_type.sh
# Run it: ./organize_by_type.sh | Organize a specific directory: ./organize_by_type.sh /path/to/folder

# ⸻
# Wrap it into a function in .zshrc for reuse <---- zsh-compatible uppercase conversion: #!/bin/bash

organize_by_extension() {
  local root_dir="${1:-.}"
  cd "$root_dir" || { echo "❌ Directory not found: $root_dir"; return 1; }
  echo "📂 Recursively organizing files in: $root_dir"
  
  # Create temporary file to track processed files
  local temp_file=$(mktemp)
  
  # Find all files and collect them with metadata
  find "$root_dir" -type f | while read -r file; do
    # Skip hidden files
    [[ "$(basename "$file")" == .* ]] && continue
    
    # Skip files already inside Extension_ folders or EXISTING folder
    rel_path="${file#$root_dir/}"
    top_folder="${rel_path%%/*}"
    [[ "$top_folder" =~ ^Extension_ || "$top_folder" == "EXISTING" ]] && continue
    
    filename="$(basename "$file")"
    base="${filename%.*}"
    ext="${filename##*.}"
    
    # Skip files without extension
    [[ "$ext" == "$filename" ]] && continue
    
    ext_upper="${(U)ext}"
    dest_dir="$root_dir/Extension_$ext_upper"              # ✨ CHANGED
    dest_file="$dest_dir/$filename"
    existing_dir="$root_dir/EXISTING/Extension_$ext_upper" # ✨ CHANGED
    
    # Create destination directory
    mkdir -p "$dest_dir"
    
    # Get file size and hash
    file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    file_hash=$(shasum "$file" | awk '{print $1}')
    
    if [[ ! -e "$dest_file" ]]; then
      # Case 1: No conflict, move normally
      mv "$file" "$dest_file"
      echo "✅ Moved: $file → $dest_file"
    else
      # File with same name exists, check size and content
      existing_size=$(stat -f%z "$dest_file" 2>/dev/null || stat -c%s "$dest_file" 2>/dev/null)
      existing_hash=$(shasum "$dest_file" | awk '{print $1}')
      
      if [[ "$file_size" != "$existing_size" ]]; then
        # Case 2: Same name, different size - rename and move to type folder
        count=1
        while [[ -e "$dest_dir/${base}_$count.$ext" ]]; do
          ((count++))
        done
        new_name="${base}_$count.$ext"
        mv "$file" "$dest_dir/$new_name"
        echo "📁 Different size - renamed and moved: $file → $dest_dir/$new_name"
      elif [[ "$file_hash" == "$existing_hash" ]]; then
        # Case 4: Same name, same size, same content - remove duplicate
        echo "🗑️  Exact duplicate removed: $file"
        rm "$file"
      else
        # Case 3 & 5: Same name, same size, different content - move to EXISTING
        mkdir -p "$existing_dir"
        existing_dest="$existing_dir/$filename"
        
        if [[ ! -e "$existing_dest" ]]; then
          # First conflict file goes to EXISTING with original name
          mv "$file" "$existing_dest"
          echo "🔄 Different content - moved to EXISTING: $file → $existing_dest"
        else
          # Additional conflicts get numbered in EXISTING
          count=1
          while [[ -e "$existing_dir/${base}_$count.$ext" ]]; do
            # Check if this one is also a duplicate
            existing_conflict_hash=$(shasum "$existing_dir/${base}_$count.$ext" | awk '{print $1}')
            if [[ "$file_hash" == "$existing_conflict_hash" ]]; then
              echo "🗑️  Duplicate found in EXISTING - removed: $file"
              rm "$file"
              break
            fi
            ((count++))
          done
          
          # If file wasn't removed as duplicate, move it with new number
          if [[ -e "$file" ]]; then
            new_existing_name="${base}_$count.$ext"
            mv "$file" "$existing_dir/$new_existing_name"
            echo "🔄 Different content - moved to EXISTING: $file → $existing_dir/$new_existing_name"
          fi
        fi
      fi
    fi
  done
  
  # Clean up
  rm -f "$temp_file"
  echo "🎉 Done organizing with proper deduplication and conflict resolution."
}

# Apply the change without restarting terminal: source ~/.zshrc
### Then use it anytime like: organize_by_extension ~/Downloads/mix

# JPG/cat.jpg ← first copyEXISTING/JPG/cat.jpg ← second one (moved here due to content conflict) | Skipping duplicate (same content)
# shasum — Checks File Content Uniquely
## incoming_hash=$(shasum "$file" | awk '{print $1}')
## existing_hash=$(shasum "$dest_file" | awk '{print $1}')
# It calculates a SHA-1 checksum for each file. That checksum:
# 	•	Is generated based on entire file content (byte-by-byte)
# 	•	Even if only one pixel changes in an image, the checksum will be different
# 	•	So even same-named, same-sized JPEGs will be identified as different, if their content differs
# If you want even stronger certainty, you could use shasum -a 256 (SHA-256) or md5.
## incoming_hash=$(shasum -a 256 "$file" | awk '{print $1}')
## existing_hash=$(shasum -a 256 "$dest_file" | awk '{print $1}')

