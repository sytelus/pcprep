#!/usr/bin/python3
import re
def main():
    with open("/etc/resolv.conf", 'rt') as f:
        lines = f.readlines()
    found = False
    for line in lines:
        if "10.50.10.50" in line:
            found = True
    if not found:
        lines.insert(0, "nameserver 10.50.10.50")
    with open("/etc/resolv.conf", 'wt') as f:
        f.write('\n'.join(lines))
if __name__ == '__main__':
    main()