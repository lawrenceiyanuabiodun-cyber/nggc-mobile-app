with open(r'C:\dev\nggc\mobile_app\lib\services\update_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'final oneDayMs = 24 * 60 * 60 * 1000;',
    'const oneDayMs = 24 * 60 * 60 * 1000;'
)

with open(r'C:\dev\nggc\mobile_app\lib\services\update_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed const warning")
