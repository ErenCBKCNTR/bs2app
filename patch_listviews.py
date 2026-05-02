import os
import re

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # We'll replace `ListView.builder(` where it doesn't already have addAutomaticKeepAlives
    # We will use regex to find ListView.builder( and simply append addAutomaticKeepAlives: false, addRepaintBoundaries: true, 
    # But wait, if it already exists, replace it or ignore
    if 'ListView.builder(' in content:
        if 'addAutomaticKeepAlives' not in content:
            new_content = content.replace('ListView.builder(', 'ListView.builder(\naddAutomaticKeepAlives: false,\naddRepaintBoundaries: true,')
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
        else:
            # maybe it has it somewhere, we'll try carefully
            pass

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))

print("ListViews patched!")
