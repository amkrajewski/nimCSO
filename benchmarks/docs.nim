## # Benchmarking
## The key performance advantage of nimCSO comes from how it handles checking how many datapoints would have to be removed if a given set of elements were removed. You can quickly compare performance (speed and memory usage) of nimCSO to other approaches based on (a) native ``Python`` sets and (b) well-optimized ``NumPy`` implementation. 
## 
## In the ``benchmarks`` directory, you will find 3 scripts, which will automatically ingest the example dataset we ship (``alloyList.txt``) with 2,150 data points and try to remove all entries containing elements from a fixed set of 5 ("Fe", "Cr", "Ni", "Co", "Al", "Ti"). This is repeated thousands of times to get a good average, but should not take more than several seconds on a modern machine.
## 
## - ``nimcso.nim`` - The ``nimCSO`` implementation based around ``BitArray``s. From the root of the project, you can run it with a simple:
##   ```cmd
##   nim c -r -f -d:release --threads:off benchmarks/nimcso
##   ```
## - ``nativePython.py`` - A ``Python`` implementation using its native sets. If you have ``python`` (3.11 is recommended) installed, you can run it with:
##   ```cmd
##   python benchmarks/nativePython.py
##   ```
## - ``pythonNumPy.py`` - A ``Python`` implementation using ``NumPy``. If you have ``python`` (3.11 is recommended) and ``numpy`` (v1.25+ is recommended) installed, you can run it with:
##   ```cmd
##   python benchmarks/pythonNumPy.py
##   ```
## You should see results roughly aligning with the following (run on MacBook M2 Pro):
## 
## | Method | Time Per Dataset [µs] | Time per Entry [ns] | Relative Speed | Representation Size [kB] | Relative Size |
## |:-------|:---------------------:|:-------------------:|:--------------:|:------------------------:|:-------------:|
## | Native Python (3.11.8) | 327.4 | 152.3 | x1 | 871.5 | x1 |
## | NumPy (1.26.4) | 40.1  | 18.6 | x8.3 | 79.7 | x10.9 |
## | nimCSO BitArray (0.5.0) | 9.2 | 4.4 | x34.6 | 50.4 | x17.3 |