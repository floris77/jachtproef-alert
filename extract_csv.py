#!/usr/bin/env python3
import re

with open('temp_result.json', 'r', encoding='utf-8') as f:
    raw = f.read()

# Use regex to extract the csv_data value (between "csv_data": ") and ", "csv_filename")
m = re.search(r'"csv_data":\s*"(.*?)",\s*"csv_filename"', raw, re.DOTALL)
if not m:
    print('❌ Could not find csv_data in the response!')
    exit(1)

csv_escaped = m.group(1)

# Decode escape sequences
csv_data = bytes(csv_escaped, 'utf-8').decode('unicode_escape')

with open('/Users/florisvanderhart/Desktop/jachtproef_all_matches_real.csv', 'w', encoding='utf-8') as f:
    f.write(csv_data)

print('✅ CSV file created successfully on your Desktop!') 