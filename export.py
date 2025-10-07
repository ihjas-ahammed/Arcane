import zipfile
import os
import fnmatch
import subprocess

def is_ignored(path, gitignore_patterns):
    """
    Checks if a file or directory should be ignored based on .gitignore patterns.

    Args:
        path (str): The path to the file or directory.
        gitignore_patterns (list): A list of patterns from the .gitignore file.

    Returns:
        bool: True if the path should be ignored, False otherwise.
    """
    for pattern in gitignore_patterns:
        if fnmatch.fnmatch(path, pattern) or fnmatch.fnmatch(os.path.basename(path), pattern):
            return True
    return False

def read_gitignore(gitignore_path):
    """
    Reads the .gitignore file and returns a list of patterns.
    Handles comments and empty lines.  Also expands directories
    to include sub-paths.

    Args:
        gitignore_path (str): The path to the .gitignore file.

    Returns:
        list: A list of patterns from the .gitignore file.
                Returns an empty list if the file does not exist.
    """
    patterns = []
    try:
        with open(gitignore_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):  # Ignore comments and empty lines
                    pattern = line
                    if os.path.isdir(pattern):
                         pattern = os.path.join(pattern, '*')
                    patterns.append(pattern)
    except FileNotFoundError:
        print(".gitignore file not found.  Zipping all files.")
        return []
    return patterns

def zip_flutter_project(project_path, output_zip_path):
    """
    Creates a zip archive of a Flutter project, excluding files and directories
    specified in .gitignore.

    Args:
        project_path (str): The path to the Flutter project directory.
        output_zip_path (str): The path to the output zip file.
    """
    if not os.path.exists(project_path):
        print(f"Error: Project path '{project_path}' does not exist.")
        return

    gitignore_path = os.path.join(project_path, '.gitignore')
    gitignore_patterns = read_gitignore(gitignore_path)

    with zipfile.ZipFile(output_zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, _, files in os.walk(project_path):
            for file in files:
                file_path = os.path.join(root, file)
                # Get relative path for checking against .gitignore and for
                # adding to the zip file.
                relative_path = os.path.relpath(file_path, project_path)

                if not is_ignored(relative_path, gitignore_patterns):
                    zipf.write(file_path, relative_path)
                    print(f"Adding: {relative_path}")
                else:
                    print(f"Ignoring: {relative_path}")

    print(f"Successfully created zip file: {output_zip_path}")

if __name__ == "__main__":
    # Get the project path and output zip path.  You can change these,
    # or make them command-line arguments.
    project_path = '.'  # Current directory (where the script is run)
    output_zip_path = 'flutter_project.zip'
    zip_flutter_project(project_path, output_zip_path)
