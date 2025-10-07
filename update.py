# apply_snapshot.py
import os
import sys

# --- Configuration ---
SNAPSHOT_FILE = "project_snapshot.txt"
START_MARKER_PREFIX = "--- START OF FILE "
END_MARKER_PREFIX = "--- END OF FILE "
MARKER_SUFFIX = " ---"
# --- End Configuration ---

def parse_snapshot(snapshot_content):
    """
    Parses the snapshot content and yields (filename, file_content) tuples.
    """
    lines = snapshot_content.splitlines() 
    current_file_lines = None
    current_filename = None
    # Keep track of filenames already yielded to handle malformed/duplicate entries robustly
    processed_files = set()

    for line_idx, line_text in enumerate(lines):
        line = line_text # Keep original line_text for content integrity

        if line.startswith(START_MARKER_PREFIX) and line.endswith(MARKER_SUFFIX):
            if current_filename and current_filename not in processed_files:
                # A new file started before the previous one properly ended.
                # Yield what was collected for the previous file, though it's likely incomplete.
                print(f"Warning: New START_MARKER for '{line}' encountered before END_MARKER for '{current_filename}' (around line {line_idx+1}). File '{current_filename}' might be incomplete.")
                yield current_filename, "\n".join(current_file_lines)
                processed_files.add(current_filename)
            
            filename_start_index = len(START_MARKER_PREFIX)
            filename_end_index = line.rfind(MARKER_SUFFIX) # Use rfind for safety
            current_filename_candidate = line[filename_start_index:filename_end_index]
            
            if current_filename_candidate in processed_files:
                print(f"Warning: File '{current_filename_candidate}' (from line {line_idx+1}) seems to be a duplicate entry in the snapshot. Skipping this block.")
                current_filename = None # Mark as invalid to skip content lines until next valid START
                current_file_lines = None
            else:
                current_filename = current_filename_candidate
                current_file_lines = []
            
        elif line.startswith(END_MARKER_PREFIX) and line.endswith(MARKER_SUFFIX):
            if current_filename: # If we were in a valid, non-skipped file block
                expected_end_filename = line[len(END_MARKER_PREFIX):line.rfind(MARKER_SUFFIX)]
                if expected_end_filename == current_filename:
                    if current_filename not in processed_files: # Ensure it hasn't been yielded due to earlier error
                        yield current_filename, "\n".join(current_file_lines)
                        processed_files.add(current_filename)
                else:
                    print(f"Warning: Mismatched END_MARKER (around line {line_idx+1}). Expected for '{current_filename}', got for '{expected_end_filename}'. Content for '{current_filename}' might be corrupted or lost.")
                    if current_filename not in processed_files: # Try to yield what was collected if it's the first time
                         yield current_filename, "\n".join(current_file_lines)
                         processed_files.add(current_filename)

            # Reset state after an END_MARKER, regardless of perfect match or if it was a skipped block
            current_filename = None
            current_file_lines = None
            
        elif current_file_lines is not None and current_filename is not None: # We are inside a valid, non-skipped file block
            current_file_lines.append(line_text)

    # If the snapshot ends mid-file without an END_MARKER for the last file
    if current_filename and current_filename not in processed_files:
        print(f"Warning: Snapshot ended while processing file '{current_filename}'. Missing END_MARKER. File might be incomplete.")
        yield current_filename, "\n".join(current_file_lines)

def update_project_from_snapshot(snapshot_filepath):
    """
    Reads the snapshot file and updates the project files accordingly.
    """
    try:
        with open(snapshot_filepath, 'r', encoding='utf-8') as f:
            snapshot_content = f.read()
    except FileNotFoundError:
        print(f"Error: Snapshot file '{snapshot_filepath}' not found.")
        return
    except Exception as e:
        print(f"Error reading snapshot file '{snapshot_filepath}': {e}")
        return

    project_root_abs = os.path.abspath(os.getcwd())
    files_updated_count = 0
    files_created_count = 0
    dirs_created_count = 0

    for filename, file_content in parse_snapshot(snapshot_content):
        if not filename: # Should not happen with current parser, but a safeguard
            print("Warning: Encountered an entry with no filename. Skipping.")
            continue

        if filename == SNAPSHOT_FILE: # Don't let the snapshot overwrite itself
            print(f"Skipping update for '{filename}' (the snapshot file itself).")
            continue
        
        # Normalize path for the current OS
        filepath_to_write = os.path.normpath(filename)
        
        # Create an absolute path for the file to be written
        abs_target_path = os.path.abspath(filepath_to_write)
        
        # Security check: ensure the target path is truly within the project root
        # os.path.realpath resolves symbolic links for a more robust check
        if not os.path.realpath(abs_target_path).startswith(os.path.realpath(project_root_abs)):
            print(f"  SECURITY SKIP: Path '{filename}' resolves to '{os.path.realpath(abs_target_path)}', which is outside the project root '{os.path.realpath(project_root_abs)}'.")
            continue
        # Additional check to prevent writing to the project root directory itself if filename was empty or just "."
        if os.path.realpath(abs_target_path) == os.path.realpath(project_root_abs) and filepath_to_write != os.path.basename(filepath_to_write):
            print(f"  SECURITY SKIP: Attempt to write to project root directory via ambiguous path '{filename}'.")
            continue


        print(f"Processing: {filepath_to_write}")
        try:
            parent_dir = os.path.dirname(filepath_to_write)
            if parent_dir: # Ensure parent_dir is not an empty string (for files in root)
                if not os.path.exists(parent_dir):
                    os.makedirs(parent_dir)
                    print(f"  Created directory: {parent_dir}")
                    dirs_created_count += 1
            
            is_new_file = not os.path.exists(filepath_to_write)

            # Write the file, ensuring consistent LF ('\n') line endings
            with open(filepath_to_write, 'w', encoding='utf-8', newline='\n') as f:
                f.write(file_content)
            
            if is_new_file:
                print(f"  Created: {filepath_to_write}")
                files_created_count +=1
            else:
                print(f"  Updated: {filepath_to_write}")
                files_updated_count +=1

        except IOError as e:
            print(f"  IOError writing file {filepath_to_write}: {e}")
        except OSError as e:
            print(f"  OSError for file/directory {filepath_to_write}: {e}")
        except Exception as e:
            print(f"  An unexpected error occurred with {filepath_to_write}: {e}")

    print("\n--- Summary ---")
    print(f"Directories created: {dirs_created_count}")
    print(f"Files created: {files_created_count}")
    print(f"Files updated: {files_updated_count}")


if __name__ == "__main__":
    script_name = os.path.basename(sys.argv[0] or "apply_snapshot.py")
    print(f"--- Project Update Script ({script_name}) ---")
    
    current_working_dir = os.getcwd()
    snapshot_file_full_path = os.path.join(current_working_dir, SNAPSHOT_FILE)

    if not os.path.exists(snapshot_file_full_path):
        print(f"\nError: Snapshot file '{SNAPSHOT_FILE}' not found in the current directory ({current_working_dir}).")
        print(f"Please ensure this script is run from your project's root directory and '{SNAPSHOT_FILE}' exists there.")
        sys.exit(1)

    print(f"\nThis script will read '{SNAPSHOT_FILE}' and update files in the current project directory:")
    print(f"  {current_working_dir}")
    print("\nIMPORTANT: Ensure you have a backup or version control (like Git) in place before proceeding.")
    print("This operation will OVERWRITE existing files with content from the snapshot.")
    
    try:
        confirm = input("Are you sure you want to continue? (yes/no): ")
    except KeyboardInterrupt:
        print("\nUpdate cancelled by user (Ctrl+C).")
        sys.exit(0)
        
    if confirm.lower() == 'yes':
        print("\nStarting project update...\n")
        update_project_from_snapshot(snapshot_file_full_path)
        print("\nProject update process finished.")
    else:
        print("\nUpdate cancelled by user.")
    
    print("--------------------------------------")