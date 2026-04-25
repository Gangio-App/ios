import sys

content = open('/Users/admin/Desktop/gangio-ios/Gangio/Pages/Channel/Messagable/MessageableChannel.swift').read()
stack = []
lines = content.splitlines()
for line_no, line in enumerate(lines, 1):
    for char in line:
        if char == '{':
            stack.append(line_no)
        elif char == '}':
            if not stack:
                print(f"Extra closing brace at line {line_no}")
            else:
                stack.pop()

if stack:
    for line_no in stack:
        print(f"Unclosed opening brace from line {line_no}")
