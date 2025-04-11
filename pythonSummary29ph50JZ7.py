import os
import datetime

def is_text_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as file:
            file.read()
        return True
    except (UnicodeDecodeError, IOError):
        return False

def should_skip_item(item_name, identifier):
    # Skip hidden files/folders (starting with dot) or files containing the identifier
    return item_name.startswith('.') or identifier in item_name

def create_directory_tree(startpath, identifier, skip_items):
    tree = ""
    for root, dirs, files in os.walk(startpath):
        # Remove hidden directories from dirs list to prevent recursion
        dirs[:] = [d for d in dirs if not d.startswith('.') and d not in skip_items]
        
        level = root.replace(startpath, '').count(os.sep)
        indent = ' ' * 4 * level
        basename = os.path.basename(root)
        
        if basename not in skip_items and not basename.startswith('.'):
            tree += f"{indent}{basename}/\n"
            subindent = ' ' * 4 * (level + 1)
            for f in files:
                if not should_skip_item(f, identifier) and f not in skip_items:
                    tree += f"{subindent}{f}\n"
    return tree

def append_file_content(filepath, output_file):
    with open(output_file, 'a', encoding='utf-8') as out:
        relative_path = os.path.relpath(filepath)
        out.write(f"\n\n\n{relative_path}\n\"\"\"\n")
        with open(filepath, 'r', encoding='utf-8') as file:
            out.write(file.read())
        out.write("\n\"\"\"\n")

def generate_output_filenames(base_name):
    timestamp = datetime.datetime.now().strftime("%Y_%m_%d_%H_%M_%S")
    identifier = "29ph50JZ7"
    output_filename = f"{base_name}_{timestamp}_{identifier}_summary.txt"
    top_files_list_filename = f"{base_name}_{timestamp}_{identifier}_lengths.txt"
    return output_filename, top_files_list_filename

def main():
    start_directory = os.getcwd()
    base_name = 'output'
    identifier = "29ph50JZ7"
    output_filename, top_files_list_filename = generate_output_filenames(base_name)
    
    # =========== ######  SKIP LIST HERE  ###### ===========
    # You can still keep specific items to skip if needed
    skip_items = ["Vm.json", "VmSafe.json"]
    
    # Create a new txt file
    with open(output_filename, 'w', encoding='utf-8') as out:
        # Write the directory tree to the top of the file
        directory_tree = create_directory_tree(start_directory, identifier, skip_items)
        out.write(directory_tree)
    
    file_lengths = []
    # Navigate from the top of the current working directory to every file
    for root, dirs, files in os.walk(start_directory):
        # Skip hidden directories
        dirs[:] = [d for d in dirs if not d.startswith('.') and d not in skip_items]
        
        for file in files:
            if should_skip_item(file, identifier) or file in skip_items:
                continue
                
            filepath = os.path.join(root, file)
            if is_text_file(filepath):
                file_length = os.path.getsize(filepath)
                file_lengths.append((file_length, filepath))
                append_file_content(filepath, output_filename)
    
    # Sort files by length in descending order
    file_lengths.sort(reverse=True, key=lambda x: x[0])

    # Calculate the total length sum
    total_length = sum(length for length, _ in file_lengths)

    # Write the sorted list of top files by length to a new file
    with open(top_files_list_filename, 'w', encoding='utf-8') as out:
        out.write(f"Total Length: {total_length}\n\n")
        for length, filepath in file_lengths:
            relative_path = os.path.relpath(filepath)
            out.write(f"{relative_path}\n{length}\n\n")

if __name__ == '__main__':
    main()
