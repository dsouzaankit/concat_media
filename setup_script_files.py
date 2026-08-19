import os
import shutil

source_folder = 'concat'

def push_code_to_subdirectories(root_directory):
    """
    Pushes code to root and all subdirectories that contain media (mp4) files
    Args:
        root_directory (str): The path to the main directory to start scanning.
    """
    for dirpath, dirnames, filenames in os.walk(root_directory):
        if source_folder in dirpath:
            print(f"Ignoring pre-existing source folder '{source_folder}' "
                  f"subdirectories at {dirpath}!")
            continue
        media_files_in_current_dir = []
        for filename in filenames:
            if filename.lower().endswith(".mp4"):
                media_files_in_current_dir.append(filename)

        if media_files_in_current_dir:  # Only copy if media is found
            destination_folder = os.path.join(dirpath, os.path.basename(source_folder))
            try:
                shutil.copytree(source_folder, destination_folder, dirs_exist_ok=True)
                print(f"Src folder '{source_folder}' merged at: {dirpath}")
            except FileNotFoundError:
                print(f"Error: Source folder '{source_folder}' not found.")
            except Exception as e:
                print(f"An error occurred: {e}")
        else:
            print(f"No media found in directory '{dirpath}'. Skipping!")


def load_root_dirs():
    try:
        from root_dirs.local import root_dirs
    except ImportError:
        raise SystemExit(
            "Missing root_dirs.local.py. Copy root_dirs.local.example.py to "
            "root_dirs.local.py and set your media library paths."
        )
    if not root_dirs:
        raise SystemExit("root_dirs.local.py defines an empty root_dirs list.")
    return root_dirs


if __name__ == '__main__':
    for root_dir in load_root_dirs():
        push_code_to_subdirectories(root_dir)
