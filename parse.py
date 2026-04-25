with open("Stoat/Pages/Home/Home.swift") as f:
    text = f.read()

lines = text.split("\n")
indent = 0
for i in range(423, 660):
    line = lines[i]
    stripped = line.split("//")[0]
    opens = stripped.count("{")
    closes = stripped.count("}")
    indent += opens - closes
    if opens != 0 or closes != 0:
        print(f"{i+1}: {indent}  |  {line}")
    if indent <= 0 and i > 430:
        print("INDENT HIT ZERO!!!")
        break
