import os
import shutil
import hashlib
from pathlib import Path

def hash_file(filepath, block_size=65536):
    """Calculate SHA-1 hash of a file."""
    hasher = hashlib.sha1()
    with open(filepath, 'rb') as f:
        for block in iter(lambda: f.read(block_size), b''):
            hasher.update(block)
    return hasher.hexdigest()

def organize_by_extension(base_dir='.'):
    """
    Organize files by extension with smart deduplication and conflict resolution.
    
    Features:
    - Recursive file organization
    - Duplicate detection & removal (SHA-1 hash)
    - Conflict resolution (same name, different content)
    - Skips hidden files and already-organized Extension_ folders
    
    Output structure:
        Extension_JPG/
        Extension_PDF/
        Extension_MP4/
        Extension_EXISTING/
            Extension_JPG/
                photo_1.jpg
                photo_2.jpg
    """
    base_dir = os.path.abspath(base_dir)
    print(f"📂 Recursively organizing files in: {base_dir}")

    for root, dirs, files in os.walk(base_dir, topdown=True):
        # Skip Extension_ folders (including Extension_EXISTING)
        dirs[:] = [d for d in dirs if not d.startswith('Extension_')]
        
        for filename in files:
            # Skip hidden files
            if filename.startswith('.'):
                continue
            
            full_path = os.path.join(root, filename)
            
            # Get extension
            name_parts = os.path.splitext(filename)
            base_name = name_parts[0]
            ext = name_parts[1][1:].upper() if name_parts[1] else 'UNKNOWN'
            
            # Skip files without extension
            if ext == 'UNKNOWN':
                continue
            
            # Destination paths
            dest_dir = os.path.join(base_dir, f'Extension_{ext}')
            dest_file = os.path.join(dest_dir, filename)
            existing_dir = os.path.join(base_dir, 'Extension_EXISTING', f'Extension_{ext}')
            
            # Create destination directory
            os.makedirs(dest_dir, exist_ok=True)
            
            # Get file metadata
            file_size = os.path.getsize(full_path)
            file_hash = hash_file(full_path)
            
            # Case 1: No conflict - move normally
            if not os.path.exists(dest_file):
                shutil.move(full_path, dest_file)
                print(f"✅ Moved: {full_path} → {dest_file}")
                continue
            
            # File with same name exists - check size and content
            existing_size = os.path.getsize(dest_file)
            existing_hash = hash_file(dest_file)
            
            # Case 2: Same name, different size - rename and move
            if file_size != existing_size:
                count = 1
                while os.path.exists(os.path.join(dest_dir, f"{base_name}_{count}.{ext.lower()}")):
                    count += 1
                new_name = f"{base_name}_{count}.{ext.lower()}"
                new_dest = os.path.join(dest_dir, new_name)
                shutil.move(full_path, new_dest)
                print(f"📁 Different size - renamed and moved: {full_path} → {new_dest}")
                continue
            
            # Case 3: Exact duplicate (same hash) - remove
            if file_hash == existing_hash:
                os.remove(full_path)
                print(f"🗑️  Exact duplicate removed: {full_path}")
                continue
            
            # Case 4: Same name, same size, different content - move to Extension_EXISTING
            os.makedirs(existing_dir, exist_ok=True)
            existing_dest = os.path.join(existing_dir, filename)
            
            if not os.path.exists(existing_dest):
                # First conflict file
                shutil.move(full_path, existing_dest)
                print(f"🔄 Different content - moved to Extension_EXISTING: {full_path} → {existing_dest}")
            else:
                # Additional conflicts - check for duplicates in Extension_EXISTING
                count = 1
                while True:
                    numbered_file = os.path.join(existing_dir, f"{base_name}_{count}.{ext.lower()}")
                    if not os.path.exists(numbered_file):
                        # Found available slot
                        shutil.move(full_path, numbered_file)
                        print(f"🔄 Different content - moved to Extension_EXISTING: {full_path} → {numbered_file}")
                        break
                    
                    # Check if it's a duplicate of existing conflict file
                    conflict_hash = hash_file(numbered_file)
                    if file_hash == conflict_hash:
                        os.remove(full_path)
                        print(f"🗑️  Duplicate found in Extension_EXISTING - removed: {full_path}")
                        break
                    
                    count += 1

    print("🎉 Done organizing with proper deduplication and conflict resolution.")


# ⸻
# Usage Examples:
# 
# organize_by_extension()                    # Current directory
# organize_by_extension("/path/to/folder")   # Specific path
# organize_by_extension("~/Downloads")       # User's Downloads folder
