#!/usr/bin/env python3
"""
Update Xcode project.pbxproj to include all Swift files in BlackScan/BlackScan/
"""

import os
import uuid
import re

PROJECT_ROOT = "/Users/kendallwood/Desktop/byme/blackscan"
PBXPROJ_PATH = os.path.join(PROJECT_ROOT, "BlackScan/BlackScan.xcodeproj/project.pbxproj")
SWIFT_FILES_DIR = os.path.join(PROJECT_ROOT, "BlackScan/BlackScan")
APP_FILE = os.path.join(PROJECT_ROOT, "BlackScan/BlackScanApp.swift")

def generate_uuid():
    """Generate a random 24-character hex ID like Xcode uses"""
    return uuid.uuid4().hex[:24].upper()

def get_swift_files():
    """Get all Swift files in BlackScan/BlackScan/ directory"""
    swift_files = []
    for file in os.listdir(SWIFT_FILES_DIR):
        if file.endswith('.swift'):
            swift_files.append(file)
    swift_files.sort()
    return swift_files

def read_pbxproj():
    """Read project.pbxproj file"""
    with open(PBXPROJ_PATH, 'r', encoding='utf-8') as f:
        return f.read()

def write_pbxproj(content):
    """Write project.pbxproj file"""
    with open(PBXPROJ_PATH, 'w', encoding='utf-8') as f:
        f.write(content)

def remove_old_references(content, filename):
    """Remove all existing references to a file"""
    # Remove PBXFileReference entries
    pattern = rf'([A-F0-9]{{24}}) /\* {re.escape(filename)} \*/ = \{{[^}}]*?fileEncoding[^}}]*?\}};'
    content = re.sub(pattern, '', content, flags=re.MULTILINE | re.DOTALL)
    
    # Remove PBXBuildFile entries
    pattern = rf'([A-F0-9]{{24}}) /\* {re.escape(filename)} in Sources \*/ = \{{[^}}]*?\}};'
    content = re.sub(pattern, '', content, flags=re.MULTILINE | re.DOTALL)
    
    # Remove from PBXGroup children arrays
    pattern = rf'\s*[A-F0-9]{{24}} /\* {re.escape(filename)} \*/,?\n'
    content = re.sub(pattern, '', content)
    
    # Remove from PBXSourcesBuildPhase files arrays
    pattern = rf'\s*[A-F0-9]{{24}} /\* {re.escape(filename)} in Sources \*/,?\n'
    content = re.sub(pattern, '', content)
    
    return content

def add_file_reference(content, filename, file_ref_id):
    """Add PBXFileReference entry"""
    # Find the /* End PBXFileReference section */ marker
    marker = "/* End PBXFileReference section */"
    marker_pos = content.find(marker)
    
    if marker_pos == -1:
        print(f"ERROR: Could not find PBXFileReference section marker")
        return content
    
    # Special handling for BlackScanApp.swift (it's one level up)
    if filename == "BlackScanApp.swift":
        path = "../BlackScanApp.swift"
    else:
        path = filename
    
    # Create the file reference entry
    entry = f'\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {path}; sourceTree = "<group>"; }};\n'
    
    # Insert before the marker
    content = content[:marker_pos] + entry + content[marker_pos:]
    
    return content

def add_build_file(content, filename, file_ref_id, build_file_id):
    """Add PBXBuildFile entry"""
    # Find the /* End PBXBuildFile section */ marker
    marker = "/* End PBXBuildFile section */"
    marker_pos = content.find(marker)
    
    if marker_pos == -1:
        print(f"ERROR: Could not find PBXBuildFile section marker")
        return content
    
    # Create the build file entry
    entry = f'\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};\n'
    
    # Insert before the marker
    content = content[:marker_pos] + entry + content[marker_pos:]
    
    return content

def add_to_group(content, filename, file_ref_id, group_name="BlackScan"):
    """Add file reference to PBXGroup"""
    # Find the group
    pattern = rf'([A-F0-9]{{24}}) /\* {re.escape(group_name)} \*/ = \{{\s*isa = PBXGroup;\s*children = \(\s*((?:[A-F0-9]{{24}} /\*[^*]*\*/,?\s*)*)\s*\);'
    
    match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
    
    if not match:
        print(f"ERROR: Could not find group {group_name}")
        return content
    
    group_id = match.group(1)
    children_section = match.group(2)
    
    # Add our file to the children
    new_child = f'\t\t\t\t{file_ref_id} /* {filename} */,\n'
    
    # Find the position to insert (before the closing );)
    insert_pattern = rf'({group_id} /\* {re.escape(group_name)} \*/ = \{{\s*isa = PBXGroup;\s*children = \(\s*(?:[A-F0-9]{{24}} /\*[^*]*\*/,?\s*)*)'
    
    content = re.sub(insert_pattern, rf'\1{new_child}', content, count=1, flags=re.MULTILINE | re.DOTALL)
    
    return content

def add_to_sources_build_phase(content, filename, build_file_id):
    """Add build file to PBXSourcesBuildPhase"""
    # Find the Sources build phase
    pattern = r'([A-F0-9]{24}) /\* Sources \*/ = \{\s*isa = PBXSourcesBuildPhase;\s*buildActionMask = [^;]+;\s*files = \(\s*((?:[A-F0-9]{24} /\*[^*]* in Sources \*/,?\s*)*)\s*\);'
    
    match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
    
    if not match:
        print(f"ERROR: Could not find Sources build phase")
        return content
    
    phase_id = match.group(1)
    files_section = match.group(2)
    
    # Add our build file to the files array
    new_file = f'\t\t\t\t{build_file_id} /* {filename} in Sources */,\n'
    
    # Find the position to insert (before the closing );)
    insert_pattern = rf'({phase_id} /\* Sources \*/ = \{{\s*isa = PBXSourcesBuildPhase;\s*buildActionMask = [^;]+;\s*files = \(\s*(?:[A-F0-9]{{24}} /\*[^*]* in Sources \*/,?\s*)*)'
    
    content = re.sub(insert_pattern, rf'\1{new_file}', content, count=1, flags=re.MULTILINE | re.DOTALL)
    
    return content

def main():
    print("🔧 Updating Xcode project.pbxproj...")
    
    # Get list of Swift files
    swift_files = get_swift_files()
    print(f"📝 Found {len(swift_files)} Swift files in BlackScan/BlackScan/")
    
    # Add BlackScanApp.swift if it exists
    if os.path.exists(APP_FILE):
        swift_files.append("BlackScanApp.swift")
        print("📝 Found BlackScanApp.swift in BlackScan/")
    
    # Read project file
    content = read_pbxproj()
    print("✅ Read project.pbxproj")
    
    # Process each file
    for filename in swift_files:
        print(f"\n📄 Processing {filename}...")
        
        # Remove old references
        content = remove_old_references(content, filename)
        print(f"   ✓ Removed old references")
        
        # Generate new UUIDs
        file_ref_id = generate_uuid()
        build_file_id = generate_uuid()
        
        # Add new references
        content = add_file_reference(content, filename, file_ref_id)
        print(f"   ✓ Added file reference ({file_ref_id})")
        
        content = add_build_file(content, filename, file_ref_id, build_file_id)
        print(f"   ✓ Added build file ({build_file_id})")
        
        content = add_to_group(content, filename, file_ref_id)
        print(f"   ✓ Added to PBXGroup")
        
        content = add_to_sources_build_phase(content, filename, build_file_id)
        print(f"   ✓ Added to Sources build phase")
    
    # Write back
    write_pbxproj(content)
    print("\n✅ Successfully updated project.pbxproj")
    print(f"📊 Added {len(swift_files)} files to the project")

if __name__ == "__main__":
    main()
