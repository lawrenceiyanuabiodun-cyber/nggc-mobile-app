import os
folder = r'C:\dev\nggc\mobile_app\lib\screens'

# Find all files that might contain profile
for root, dirs, files in os.walk(folder):
    for f in files:
        if 'profile' in f.lower() or 'account' in f.lower() or 'settings' in f.lower():
            full = os.path.join(root, f)
            size = os.path.getsize(full)
            print(f"{full}  ({size} bytes)")
