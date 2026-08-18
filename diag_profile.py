with open(r'C:\dev\nggc\mobile_app\lib\screens\profile\profile_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()
    lines = content.split('\n')

print(f"Total lines: {len(lines)}")
print()
print("=== First 60 lines (imports + class start) ===")
for i in range(min(60, len(lines))):
    print(f"{i+1:4d} | {lines[i]}")

print()
print("=== Searching for 'ListTile' or section headers ===")
for i, line in enumerate(lines):
    if any(x in line for x in ['ListTile(', 'sectionHeader', '_section', 'About', 'Settings', 'Version', 'logout', 'signOut']):
        start = max(0, i - 1)
        end = min(len(lines), i + 3)
        for j in range(start, end):
            print(f"{j+1:4d} | {lines[j]}")
        print("---")
