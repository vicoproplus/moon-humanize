import os

cases = [
    ('pub fn f() -> Int {\n  mut s = 0\n  for i = 0; i < 3; i = i + 1 { s = s + 1 }\n  s\n}\n', 'A_baseline'),
    ('pub fn f() -> Int {\n  mut i = 0\n  for i = 0; i < 10; i = i + 1 { i = i + 1 }\n  i\n}\n', 'C_redeclare_i'),
    ('pub fn f() -> Int {\n  mut k = 0\n  for j = 0; k < 10; j = j + 1 { k = k + 1 }\n  k\n}\n', 'D_sep_vars'),
    ('pub fn f() -> Int {\n  mut i = 0\n  while i < 10 { i = i + 1 }\n  i\n}\n', 'E_while'),
]

for body, name in cases:
    open('probe/src/lib.mbt', 'w', encoding='utf-8').write(body)
    os.system('cd probe && rm -rf target >nul 2>&1')
    r = os.popen('cd probe && moon build 2>&1').read()
    err = 'Error' in r or 'error' in r.lower()
    print(name, 'ERR' if err else 'OK', '|', [l.strip() for l in r.split('\n') if 'Error' in l][:1])
