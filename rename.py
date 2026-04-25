import os
import re

def replace_in_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        return

    orig = content
    # Replace Stoat -> Gangio
    content = re.sub(r'Stoat', 'Gangio', content)
    # Replace stoat -> gangio
    content = re.sub(r'stoat', 'gangio', content)
    # Replace Revolt -> Gangio
    content = re.sub(r'Revolt', 'Gangio', content)
    # Replace revolt -> gangio
    content = re.sub(r'revolt', 'gangio', content)
    # Replace REVOLT -> GANGIO
    content = re.sub(r'REVOLT', 'GANGIO', content)
    # Replace STOAT -> GANGIO
    content = re.sub(r'STOAT', 'GANGIO', content)

    if content != orig:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

def process_dir(directory):
    for root, dirs, files in os.walk(directory):
        if '.git' in root or '.build' in root or 'DerivedData' in root:
            continue
        for file in files:
            if file.endswith(('.swift', '.pbxproj', '.plist', '.entitlements', '.xcworkspacedata', '.json', '.xcconfig')):
                replace_in_file(os.path.join(root, file))

process_dir('.')
