import time
import sys

with open('alloyList.txt', 'r') as f:
    alloyList = f.read().splitlines()
elementalList = [s.split(',') for s in alloyList]

memoryUsed = sys.getsizeof(elementalList) + \
    sum(sys.getsizeof(row) for row in elementalList) + \
    sum(sys.getsizeof(el) for row in elementalList for el in row)

print(f"Memory Used: {memoryUsed/1024:.1f} kB")

def preventedDataNative(toCheck):
    prevented = 0
    for row in elementalList:
        for el in toCheck:
            if el in row:
                prevented += 1
                break
    return prevented

assert len(elementalList)==2150
assert preventedDataNative(['Cr', 'Fe', 'Ni', 'Co', 'Al', 'Ti']) == 1955

if __name__ == '__main__':
    print("\nCount Data Points Prevented by Removal of Cr-Fe-Ni-Co-Al (Native Python)")
    t0 = time.time()
    for i in range(10000):
        preventedDataNative(['Cr', 'Fe', 'Ni', 'Co', 'Al', 'Ti'])
    time_us = (time.time() - t0) * 1e6 / 10000
    print(f"CPU Time [per dataset evaluation] {time_us:.1f} us")
    time_ns_pc = time_us * 1000 / len(elementalList)
    print(f"CPU Time [per comparison] {time_ns_pc:.1f} ns")