#!/bin/bash

# 🔹 Quick One-Liner Command (for current folder only - not recursive)
# for f in *.*; do ext="${f##*.}"; ext_upper="${(U)ext}"; mkdir -p "Extension_$ext_upper"; mv -- "$f" "Extension_$ext_upper/"; done

# ⸻
# 🚀 Advanced Recursive Organization with Deduplication & Conflict Resolution
# organize_by_extension - Organize files by extension with smart conflict handling
#
# Usage:
#   organize_by_extension              # Organize current directory
#   organize_by_extension ~/Downloads  # Organize specific path
#
# Features:
#   ✅ Recursive file organization
#   ✅ Duplicate detection & removal (using SHA-1 hash)
#   ✅ Conflict resolution (same name, different content)
#   ✅ Skips hidden files and already-organized folders
#
# Output Structure:
#   Extension_JPG/       # All .jpg files
#   Extension_PDF/       # All .pdf files
#   Extension_MP4/       # All .mp4 files
#   Extension_EXISTING/  # Conflict files (same name, different content)
#     └── Extension_JPG/
#         └── photo_1.jpg
#         └── photo_2.jpg

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
    
    # Skip files already inside Extension_ folders
    rel_path="${file#$root_dir/}"
    top_folder="${rel_path%%/*}"
    [[ "$top_folder" =~ ^Extension_ ]] && continue
    
    filename="$(basename "$file")"
    base="${filename%.*}"
    ext="${filename##*.}"
    
    # Skip files without extension
    [[ "$ext" == "$filename" ]] && continue
    
    ext_upper="${(U)ext}"
    dest_dir="$root_dir/Extension_$ext_upper"
    dest_file="$dest_dir/$filename"
    existing_dir="$root_dir/Extension_EXISTING/Extension_$ext_upper"
    
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
        # Case 3: Same name, same size, same content - remove duplicate
        echo "🗑️  Exact duplicate removed: $file"
        rm "$file"
      else
        # Case 4: Same name, same size, different content - move to Extension_EXISTING
        mkdir -p "$existing_dir"
        existing_dest="$existing_dir/$filename"
        
        if [[ ! -e "$existing_dest" ]]; then
          # First conflict file goes to Extension_EXISTING with original name
          mv "$file" "$existing_dest"
          echo "🔄 Different content - moved to Extension_EXISTING: $file → $existing_dest"
        else
          # Additional conflicts get numbered in Extension_EXISTING
          count=1
          while [[ -e "$existing_dir/${base}_$count.$ext" ]]; do
            # Check if this one is also a duplicate
            existing_conflict_hash=$(shasum "$existing_dir/${base}_$count.$ext" | awk '{print $1}')
            if [[ "$file_hash" == "$existing_conflict_hash" ]]; then
              echo "🗑️  Duplicate found in Extension_EXISTING - removed: $file"
              rm "$file"
              break
            fi
            ((count++))
          done
          
          # If file wasn't removed as duplicate, move it with new number
          if [[ -e "$file" ]]; then
            new_existing_name="${base}_$count.$ext"
            mv "$file" "$existing_dir/$new_existing_name"
            echo "🔄 Different content - moved to Extension_EXISTING: $file → $existing_dir/$new_existing_name"
          fi
        fi
      fi
    fi
  done
  
  # Clean up
  rm -f "$temp_file"
  echo "🎉 Done organizing with proper deduplication and conflict resolution."
}

# ⸻
# 📝 How SHA Hash Detection Works
#
# shasum calculates a SHA-1 checksum based on file content (byte-by-byte)
# - Same content = Same hash (even if renamed)
# - Different content = Different hash (even if 1 pixel changes)
# 
# For stronger verification, use SHA-256:
#   shasum -a 256 "$file" | awk '{print $1}'
#
# ⸻
# 💾 Installation
#
# 1. Add this function to ~/.zshrc
# 2. Apply changes: source ~/.zshrc
# 3. Use anywhere: organize_by_extension ~/Downloads
#
# ⸻
# 📊 Output Examples
#
# ✅ Moved: ./photo.jpg → ./Extension_JPG/photo.jpg
# 🗑️  Exact duplicate removed: ./photo_copy.jpg
# 📁 Different size - renamed: ./photo.jpg → ./Extension_JPG/photo_1.jpg
# 🔄 Different content - moved to Extension_EXISTING: ./photo.jpg → ./Extension_EXISTING/Extension_JPG/photo.jpg
```

---

## Key Changes from Your GitHub Version:

| Feature | Old | New |
|---------|-----|-----|
| **Folder naming** | `JPG/`, `PDF/` | `Extension_JPG/`, `Extension_PDF/` |
| **Conflict folder** | `EXISTING/JPG/` | `Extension_EXISTING/Extension_JPG/` |
| **Skip logic** | Pattern match `^[A-Z0-9]{2,5}$` | Prefix match `^Extension_` |
| **File size check** | ❌ No | ✅ Yes (faster duplicate detection) |
| **Nested conflicts** | ❌ Simple rename | ✅ Full deduplication in Extension_EXISTING |
| **DCIM bug** | ❌ Skips DCIM folder | ✅ Fixed! Processes everything |

---

## Final Output Structure:
```
Extension_AAC/
Extension_JPG/
Extension_MP4/
Extension_PDF/
Extension_PNG/
Extension_EXISTING/    ← Only created if conflicts occur
  └── Extension_JPG/
      └── photo.jpg    ← Same name, different content
      └── photo_1.jpg  ← Another conflict
