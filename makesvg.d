/// Creates a SVG file illustrating compilation times.
module makesvg;

import std.algorithm;
import std.conv;
import std.exception;
import std.file;
import std.path;
import std.string;

import ae.utils.json;
import ae.utils.xml;

import common;

void main(string[] args)
{
	enforce(args.length == 2, "Usage: " ~ args[0] ~ " FILE.dbuildstat");
	auto modules = args[1].readText().jsonParse!(Module[])();
	modules.sort!`a.name < b.name`();

	enum WIDTH = 700;
	enum CENTER = WIDTH/2;
	enum ROW_HEIGHT = 30;
	enum TOP = ROW_HEIGHT;
	enum PIXELS_PER_SECOND = 300;
	enum TICKS_PER_PIXEL = TICKS_PER_SECOND / PIXELS_PER_SECOND;
	enum TEXT_X = CENTER + ROW_HEIGHT/2;
	enum TEXT_SIZE = ROW_HEIGHT*3/4;
	enum TEXT_HEIGHT = TEXT_SIZE;

	auto seconds = CENTER/PIXELS_PER_SECOND;

	auto svg = newXml().svg();
	svg.xmlns = "http://www.w3.org/2000/svg";
	svg["version"] = "1.1";
	svg.width  = text(WIDTH);
	svg.height = text(TOP + (modules.length + 2 + Metric.max) * ROW_HEIGHT);

	auto defs = svg.defs();
	auto grad = defs.linearGradient(["id" : "fade", "x1" : "0%", "y1" : "0%", "x2" : "0%", "y2" : "100%"]);
	grad.stop(["offset" :   "0%", "style" : "stop-color: rgb(255, 255, 255); stop-opacity: 0.3"]);
	grad.stop(["offset" : "100%", "style" : "stop-color: rgb(255, 255, 255); stop-opacity: 0"  ]);

	static void line(XmlBuildNode g, double x1, double y1, double x2, double y2) { g.line(["x1" : text(x1), "y1" : text(y1), "x2" : text(x2), "y2" : text(y2)]); }
	static void hline(XmlBuildNode g, double x1, double x2, double y) { line(g, x1, y, x2, y); }
	static void vline(XmlBuildNode g, double x, double y1, double y2) { line(g, x, y1, x, y2); }
	static void label(XmlBuildNode g, double x, double y, string s) { g.text(["x" : text(x), "y" : text(y + TEXT_HEIGHT)]) = s; }
	static void rect(XmlBuildNode g, double x, double y, double w, double h, string fill) { g.rect(["x" : text(x), "y" : text(y), "width" : text(w), "height" : text(h), "fill" : fill]); }
	static void shadedRect(XmlBuildNode g, double x, double y, double w, double h, string fill) { rect(g, x, y, w, h, fill); rect(g, x, y, w, h, "url(#fade)"); }

	auto grid = svg.g();
	grid.style = "stroke:rgb(200,200,200); stroke-width:2";
	foreach (y; 0..modules.length+1)
		hline(grid, 0, WIDTH, TOP + y * ROW_HEIGHT);
	foreach (x; 0..seconds+1)
		vline(grid, CENTER - x*PIXELS_PER_SECOND, TOP, TOP + modules.length * ROW_HEIGHT);

	auto timeLabels = svg.g();
	timeLabels.style = "text-anchor: middle; font-size: " ~ text(TEXT_SIZE) ~ "px";
	timeLabels.title() = "(seconds)";
	foreach (x; 0..seconds+1)
		label(timeLabels, CENTER - x*PIXELS_PER_SECOND, 0, text(x));

	enum string[Metric.max] METRIC_NAMES  = ["Parse imports", "Parse", "Compile"];
	enum string[Metric.max] METRIC_COLORS = ["#2222FF", "#00CC00", "#FF0000"];

	auto boxes = svg.g();
	auto labels = svg.g();
	labels.style = "font-size: " ~ text(TOP * 3 / 4) ~ "px";
	foreach (y, m; modules)
	{
		auto rowY = TOP + y * ROW_HEIGHT;
		foreach_reverse(metric, time; m.bestTime)
		{
			auto g = boxes.g();
			long relTime = time - (metric ? m.bestTime[metric-1] : 0);
			if (relTime < 0) continue;
			g.title() = format("%s - %5.3f seconds", METRIC_NAMES[metric], relTime * 1.0 / TICKS_PER_SECOND);
			auto w = time * 1.0 / TICKS_PER_PIXEL;
			shadedRect(g, CENTER - w, rowY, w, ROW_HEIGHT, METRIC_COLORS[metric]);
		}

		label(labels, TEXT_X, rowY, m.name);
	}

	auto legend = svg.g();
	auto legendText = svg.g();
	legend.style = "stroke:black; stroke-width:1";
	legendText.style = "font-size: " ~ text(TOP * 3 / 4) ~ "px";

	auto legendY = TOP + (modules.length + 1) * ROW_HEIGHT;
	label(legendText, TEXT_X, legendY, "Legend:");
	legendY += ROW_HEIGHT;

	foreach (metric; Metric.init..Metric.max)
	{
		shadedRect(legend, CENTER - ROW_HEIGHT*1/4, legendY + metric * ROW_HEIGHT + ROW_HEIGHT*1/4, ROW_HEIGHT/2, ROW_HEIGHT/2, METRIC_COLORS[metric]);
		label(legendText, TEXT_X, legendY + metric * ROW_HEIGHT, METRIC_NAMES[metric]);
	}

	args[1].setExtension("svg").write(svg.toString());
}
