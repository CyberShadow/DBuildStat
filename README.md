DBuildStat
==========

Measure and visualize per-module build times of D projects.

Usage
-----

1. Download the project code, including submodules:

        git clone --recursive https://github.com/CyberShadow/DBuildStat

2. Run `dbuildstat` to gather profile data, e.g.:

        rdmd dbuildstat program.d

   If needed, pass any necessary compiler switches (e.g. include paths) to `dbuildstat` before the program name.

   By default, `dbuildstat` will keep gathering samples forever.
   Stop the program to cancel any time, or use the `--iterations` switch to limit to a set number of iterations.

   For more usage information, run the program without any parameters.

3. `dbuildstat`  will create a `program.dbuildstat` file. You can use this as input for the other programs:

   - `printtimes` will simply print gathered times as text to standard output.
   - `makedot` will make a [Graphviz](http://www.graphviz.org/) Dot file containing the module dependencies.
   - `makesvg` will create a SVG chart of the measured build times of each module.
