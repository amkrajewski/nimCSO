# Quick Start

This is a quick start guide to get you up and running with the nimCSO software. **If you are running it in the Codespaces environment, everything is prepared for you**, and you should now open the [**`quickstart.ipynb`**](quickstart.ipynb) notebook inside this directory and follow the instructions there. *Please note, that once prompted to select a kernel (after running the first code cell), you should select the `base` kernel (which should show up as recommended).*

Alternatively, if you want to start playing with the CLI directly, you can compile the tool using the command below. It will use the default `config.yaml` file pointing to the `dataList.txt` and should take just a few seconds.

```sh
nim c -r -f -d:release src/nimcso
```

Once the above is run, you will see the `help` printout showing you your options. You can either add them on top of the previous command, which will recompile the tool, like

```sh
nim c -r -f -d:release src/nimcso --geneticSearch
```

or use the already compiled runtime

```sh
./src/nimcso.out -gs
```
