/// Creates a GraphViz .dot file from the dependency graph.
module makedot;

import std.exception;
import std.file;
import std.path;

import ae.utils.json;
import ae.utils.text;
import ae.utils.textout;

import common;

void main(string[] args)
{
	enforce(args.length == 2, "Usage: " ~ args[0] ~ " FILE.dbuildstat");
	auto modules = args[1].readText().jsonParse!(Module[])();
	bool[string][string] deps;
	foreach (m; modules)
	{
		deps[m.name] = null;
		foreach (i; m.deps.keys)
			deps[m.name][i] = true;
	}

	auto allModules = deps.keys;

	// Remove redundant edges.
	// Attempts to preserve the general purpose of the graph,
	// while removing most edges.
	bool changed;
	do
	{
		changed = false;
		foreach (m0; allModules)
			foreach (m1; allModules)
				foreach (m2; allModules)
				if (m1 in deps[m0] && m2 in deps[m1] && m2 in deps[m0])
				{
					deps[m0].remove(m2);
					changed = true;
				}

	} while (changed);

	StringBuilder s;
	s.put("digraph {\n");
	foreach (src, dsts; deps)
	{
		foreach (dst, b; dsts)
			s.put('"', src, "\" -> \"", dst, "\";\n");
		s.put('\n');
	}
	s.put("}\n");

	args[1].setExtension("dot").write(s.get());
}
