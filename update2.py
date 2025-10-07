import os
import re

def apply_diff(diff_file_path="changes.txt"):
    """
    Applies changes from a diff file to the project.

    Args:
        diff_file_path (str): Path to the diff file (e.g., 'changes.txt').
    """
    if not os.path.exists(diff_file_path):
        print(f"Error: Diff file '{diff_file_path}' not found.")
        return

    with open(diff_file_path, 'r', encoding='utf-8') as f:
        diff_content = f.readlines()

    current_file_path = None
    original_lines = []
    new_lines = []
    original_line_idx = 0
    applying_hunk = False

    def write_changes_to_file(file_path, lines_to_write):
        if file_path is None:
            return
        try:
            # Ensure directory exists for new files
            dir_name = os.path.dirname(file_path)
            if dir_name and not os.path.exists(dir_name):
                os.makedirs(dir_name)
                print(f"Created directory: {dir_name}")

            with open(file_path, 'w', encoding='utf-8', newline='\n') as wf:
                wf.writelines(l + '\n' for l in lines_to_write) # Ensure newline
            print(f"Applied changes to: {file_path}")
        except IOError as e:
            print(f"Error writing to file {file_path}: {e}")
        except Exception as e:
            print(f"An unexpected error occurred while writing {file_path}: {e}")


    for i, line_content in enumerate(diff_content):
        line = line_content.rstrip('\n') # Keep original line endings in mind later

        if line.startswith("--- a/"):
            # Finish processing the previous file if any
            if current_file_path and new_lines:
                write_changes_to_file(current_file_path, new_lines)

            # Reset for the new file
            original_lines = []
            new_lines = []
            original_line_idx = 0
            applying_hunk = False

            old_file_path_diff = line[len("--- a/"):].strip()
            if old_file_path_diff == "dev/null":
                # This indicates a new file, original_lines will be empty
                current_file_path = None # Will be set by +++ line
                original_lines = []
                print(f"Preparing for new file creation.")
            else:
                current_file_path = old_file_path_diff
                if os.path.exists(current_file_path):
                    try:
                        with open(current_file_path, 'r', encoding='utf-8') as cf:
                            original_lines = [l.rstrip('\n') for l in cf.readlines()]
                        print(f"Processing file: {current_file_path}")
                    except FileNotFoundError:
                        print(f"Error: Original file '{current_file_path}' not found for '---' line.")
                        current_file_path = None # Error state
                    except Exception as e:
                        print(f"Error reading file {current_file_path}: {e}")
                        current_file_path = None
                else:
                    print(f"Warning: Original file '{current_file_path}' specified by '---' not found. Assuming new file if '+++' specifies one.")
                    original_lines = [] # Treat as new if original is missing

        elif line.startswith("+++ b/"):
            new_file_path_diff = line[len("+++ b/"):].strip()
            if new_file_path_diff == "dev/null":
                print(f"File deletion indicated for {current_file_path}. This script will not delete it.")
                # To implement deletion: os.remove(current_file_path)
                current_file_path = None # Stop processing this file
                new_lines = [] # Clear any potential new lines
            else:
                # If it's a new file creation, --- a/dev/null was processed
                # current_file_path might be None, so set it from +++
                if current_file_path is None or old_file_path_diff == "dev/null":
                     current_file_path = new_file_path_diff
                     print(f"Setting current file (likely new) to: {current_file_path}")


        elif line.startswith("@@"):
            applying_hunk = True
            # We could parse hunk starts for more robust application,
            # but for this simpler version, we'll rely on context lines matching.
            hunk_info_match = re.match(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
            if hunk_info_match:
                # old_start = int(hunk_info_match.group(1))
                # new_start = int(hunk_info_match.group(3))
                # original_line_idx = old_start - 1 # Adjust to 0-based index
                # For this simpler version, we just continue to match lines
                pass


        elif applying_hunk and current_file_path:
            if line.startswith("+"):
                new_lines.append(line[1:])
            elif line.startswith("-"):
                if original_line_idx < len(original_lines):
                    # Check if the line to be removed actually matches
                    expected_line = line[1:]
                    actual_line = original_lines[original_line_idx]
                    if expected_line == actual_line:
                        original_line_idx += 1
                    else:
                        print(f"Error: Mismatch in file {current_file_path} at original line {original_line_idx + 1}.")
                        print(f"  Expected to remove: '{expected_line}'")
                        print(f"  Found in file:    '{actual_line}'")
                        print("  Aborting changes for this file. Please check the diff or file content.")
                        # Reset this file's processing
                        new_lines = original_lines[:] # Revert to original for this file
                        applying_hunk = False # Stop processing hunks for this file
                        # Consider stopping entirely or just skipping this file
                        current_file_path = None # Mark as error for this file
                else:
                    print(f"Error: Trying to remove line beyond end of original file {current_file_path}.")
                    current_file_path = None
            elif line.startswith(" "): # Context line
                context_line_content = line[1:]
                if original_line_idx < len(original_lines):
                    if original_lines[original_line_idx] == context_line_content:
                        new_lines.append(context_line_content)
                        original_line_idx += 1
                    else:
                        print(f"Error: Context mismatch in file {current_file_path} at original line {original_line_idx + 1}.")
                        print(f"  Expected context: '{context_line_content}'")
                        print(f"  Found in file:  '{original_lines[original_line_idx]}'")
                        print("  Aborting changes for this file. Please check the diff or file content.")
                        new_lines = original_lines[:]
                        applying_hunk = False
                        current_file_path = None
                else: # Context line points beyond the end of the original file
                    print(f"Error: Context line for {current_file_path} goes beyond original file content.")
                    print(f"  Context line: '{context_line_content}'")
                    new_lines = original_lines[:]
                    applying_hunk = False
                    current_file_path = None
            else: # Should not happen in a valid diff hunk
                if line.strip(): # if not an empty line
                    print(f"Warning: Unexpected line in hunk for {current_file_path}: '{line}'")

    # Write changes for the very last file in the diff
    if current_file_path and (new_lines or not os.path.exists(current_file_path)): # write if new_lines has content or if it's a new empty file
        # If original_lines is not fully consumed by context/deletions, append remaining
        if original_line_idx < len(original_lines):
             print(f"Appending remaining {len(original_lines) - original_line_idx} original lines for {current_file_path}")
             new_lines.extend(original_lines[original_line_idx:])
        write_changes_to_file(current_file_path, new_lines)

    print("Diff application process finished.")

if __name__ == "__main__":
    # Create a dummy project structure for testing
    # Test file 1
    if not os.path.exists("src"):
        os.makedirs("src")
    with open("src/example.txt", "w") as f:
        f.write("This is the first line.\n")
        f.write("This is the second line, to be changed.\n")
        f.write("This is the third line.\n")
        f.write("Another line to be removed.\n")

    # Test file 2 (will be created by diff)
    if os.path.exists("src/new_file.txt"):
        os.remove("src/new_file.txt")
    
    # Test file 3 (empty file, to be modified)
    with open("src/empty_to_fill.txt", "w") as f:
        pass

    print("----- APPLYING  DIFF -----")
    apply_diff("changes.txt")
    print("----- FINISHED APPLYING  DIFF -----")

    # Verify (optional)
    print("\nContents of src/example.txt after diff:")
    if os.path.exists("src/example.txt"):
        with open("src/example.txt", "r") as f:
            print(f.read())
    else:
        print("src/example.txt not found.")

    print("\nContents of src/new_file.txt after diff:")
    if os.path.exists("src/new_file.txt"):
        with open("src/new_file.txt", "r") as f:
            print(f.read())
    else:
        print("src/new_file.txt not found.")
    
    print("\nContents of src/empty_to_fill.txt after diff:")
    if os.path.exists("src/empty_to_fill.txt"):
        with open("src/empty_to_fill.txt", "r") as f:
            print(f.read())
    else:
        print("src/empty_to_fill.txt not found.")

    # Clean up dummy files
    # os.remove("changes.txt")
    # os.remove("src/example.txt")
    # if os.path.exists("src/new_file.txt"): os.remove("src/new_file.txt")
    # if os.path.exists("src/empty_to_fill.txt"): os.remove("src/empty_to_fill.txt")
    # if os.path.exists("src"): os.rmdir("src") # only if empty