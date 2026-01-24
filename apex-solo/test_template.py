from pathlib import Path
template = Path('prompts/driver.md').read_text()
try:
    result = template.format(task='Test')
    print('OK - inga format-fel')
except KeyError as e:
    print(f'KeyError: {e}')
