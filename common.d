enum Metric
{
	parseImports,
	import_,
	parse,
	compile,
	max
}

struct Module
{
	string name, path;
	string[string] deps;
	ulong[Metric.max] bestTime = ulong.max;
}

import core.time;

enum TICKS_PER_SECOND = convert!("seconds", "hnsecs")(1);
