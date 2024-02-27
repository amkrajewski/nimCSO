## # Tests
## 
## ``nimCSO`` uses ``unittest`` to test (1) all results-producing functions for accuracy against known references, and (2) all of the available functions in the package for runtime errors. 
## All tests are within the ``tests`` directory and can be run in one-go with ``tests/runAll`` script using the following command:
## 
## ```cmd
## nim c -f -r -d:release -d:configPath=tests/config.yaml tests/runAll
## ```
## 
## which, as one can see, uses the ``test/config.yaml`` file to configure the tests for a smaller set of elements (to reduce runtime) and a custom alloy data file ``tests/testAlloyList1.txt``,
## which includes some elements like unobtanium (``Ub``) to verify filtering works as expected.
## 