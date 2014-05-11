/// Attempt to get stats for build times of D programs.
/// Creates a .dbuildstat file, which can then be analyzed by other tools.
/// Runs indefinitely by default. Saves data after every iteration. Stop when enough precision is accumulated.
module dbuildstat;

import std.algorithm;
import std.array;
import std.datetime;
import std.exception;
import std.getopt;
import std.file;
import std.path;
import std.process;
import std.stdio : stderr;
import std.string;

import ae.sys.cmd;
import ae.utils.json;
import ae.utils.regex;

import common;

alias std.string.join join; // Issue 314

void main(string[] args)
{
	int iterations = int.max;
	bool useVerboseOutput;
	getopt(args,
		config.passThrough,
		"iterations", &iterations,
		"use-verbose-output", &useVerboseOutput,
	);

	enforce(args.length > 1, "Usage: " ~ args[0] ~ " [--iterations=ITERATIONS] [--use-verbose-output] [COMPILER-OPTS...] PROGRAM.d");
	auto program = args[$-1];
	auto options = args[1..$-1];

	Module[] modules;

	stderr.writeln("Getting file list...");

	if (useVerboseOutput)
	{
		string[string] getDeps(string target)
		{
			string[string] result;
			auto lines = query(["dmd", "-v", "-o-"] ~ options ~ [target]).splitLines();
			foreach (line; lines)
				if (line.startsWith("import    "))
					result[line.split("\t")[0][10..$]] = line.split("\t")[1][1..$-1].buildNormalizedPath();
			return result;
		}

		auto rootDeps = getDeps(program);
		modules ~= Module(program.stripExtension(), absolutePath(program), rootDeps);
		foreach (name; rootDeps.keys.sort)
			modules ~= Module(name, rootDeps[name]);

		stderr.writeln("Getting module dependencies...");
		foreach (ref m; modules)
		{
			stderr.writeln(m.name);
			m.deps = getDeps(m.path);
		}
	}
	else
	{
		Module* getModule(string name, string path)
		{
			foreach (ref m; modules)
				if (m.name == name)
					return &m;
			modules ~= Module(name, path);
			return &modules[$-1];
		}

		auto depsFile = program.setExtension(".deps");
		run(["dmd", "-deps=" ~ depsFile, "-o-"] ~ options ~ [program]);
		foreach (line; depsFile.readText().splitLines())
			// awesome (awesome.d) : private : object (C:\\Soft\\dmd2d\\windows\\bin\\..\\..\\import\\druntime\\object.di)
			line.matchCaptures(`^(.*) \((.*)\) : \w+ : (.*) \((.*)\)$`,
				(string srcName, string srcPath, string dstName, string dstPath)
				{
					getModule(srcName, srcPath).deps[dstName] = dstPath;
					getModule(dstName, dstPath); // make sure it's added
				});
	}

	auto workDir = buildPath(tempDir(), "dbuildstat");

	foreach (iteration; 0..iterations)
	{
		program.setExtension("dbuildstat").write(modules.toJson());

		stderr.writefln("=== Iteration %d ===", iteration);

		foreach (ref m; modules)
		{
			stderr.writeln(m.name);

			foreach (metric; Metric.init..Metric.max)
			{
				if (exists(workDir))
					rmdirRecurse(workDir);
				mkdir(workDir);
				scope(exit) rmdirRecurse(workDir);

				string[] metricOptions;
				string target = m.path;
				switch (metric)
				{
					case Metric.parseImports:
						target = buildPath(workDir, "justimports.d");
						auto imports = m.deps.keys.filter!(s => s != "object")().array();
						target.write(imports.length ? "import " ~ imports.join(",") ~ ";" : "");
						metricOptions = ["-o-"];
						break;
					case Metric.parse:
						metricOptions = ["-o-"];
						break;
					case Metric.compile:
						metricOptions = ["-c"];
						break;
					default:
						assert(0);
				}

				StopWatch sw;
				sw.start();
				run(["dmd", "-od" ~ workDir] ~ metricOptions ~ options ~ [target]);
				sw.stop();
				auto result = sw.peek().to!("hnsecs", ulong)();
				m.bestTime[metric] = min(m.bestTime[metric], result);
			}
		}
	}
}
