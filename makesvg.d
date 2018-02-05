/// Creates a SVG file illustrating compilation times.
module makesvg;

import std.algorithm;
import std.conv;
import std.exception;
import std.file;
import std.path;
import std.string;

import ae.utils.funopt;
import ae.utils.json;
import ae.utils.main;
import ae.utils.xml;

import common;

void makesvg(
	Parameter!(string, "FILE.dbuildstat", "inputFile") fileName,
	Option!int width = 700,
	Option!int rowHeight = 30,
)
{
	auto modules = fileName.readText().jsonParse!(Module[])();
	modules.sort!`a.name < b.name`();

	ulong longestTime = 0;
	foreach (m; modules)
		foreach (metric, time; m.bestTime)
			if (longestTime < time)
				longestTime = time;

	auto center = width / 2;
	auto ticksPerPixel = cast(ulong)(longestTime * 1.1 / center);
	auto pixelsPerSecond = TICKS_PER_SECOND / ticksPerPixel;
	auto svgTop = rowHeight;
	// auto ticksPerPixel = TICKS_PER_SECOND / pixelsPerSecond;
	auto textX = center + rowHeight/2;
	auto textSize = rowHeight*3/4;
	auto textHeight = textSize;

	auto seconds = center/pixelsPerSecond;

	auto svg = newXml().svg();
	svg.xmlns = "http://www.w3.org/2000/svg";
	svg["version"] = "1.1";
	svg.width  = text(width);
	svg.height = text(svgTop + (modules.length + 2 + Metric.max) * rowHeight);

	auto defs = svg.defs();
	auto grad = defs.linearGradient(["id" : "fade", "x1" : "0%", "y1" : "0%", "x2" : "0%", "y2" : "100%"]);
	grad.stop(["offset" :   "0%", "style" : "stop-color: rgb(255, 255, 255); stop-opacity: 0.3"]);
	grad.stop(["offset" : "100%", "style" : "stop-color: rgb(255, 255, 255); stop-opacity: 0"  ]);

	void line(XmlBuildNode g, double x1, double y1, double x2, double y2) { g.line(["x1" : text(x1), "y1" : text(y1), "x2" : text(x2), "y2" : text(y2)]); }
	void hline(XmlBuildNode g, double x1, double x2, double y) { line(g, x1, y, x2, y); }
	void vline(XmlBuildNode g, double x, double y1, double y2) { line(g, x, y1, x, y2); }
	void label(XmlBuildNode g, double x, double y, string s) { g.text(["x" : text(x), "y" : text(y + textHeight)]) = s; }
	void rect(XmlBuildNode g, double x, double y, double w, double h, string fill) { g.rect(["x" : text(x), "y" : text(y), "width" : text(w), "height" : text(h), "fill" : fill]); }
	void shadedRect(XmlBuildNode g, double x, double y, double w, double h, string fill) { rect(g, x, y, w, h, fill); rect(g, x, y, w, h, "url(#fade)"); }

	auto grid = svg.g();
	grid.style = "stroke:rgb(200,200,200); stroke-width:2";
	foreach (y; 0..modules.length+1)
		hline(grid, 0, width, svgTop + y * rowHeight);
	foreach (x; 0..seconds+1)
		vline(grid, center - x*pixelsPerSecond, svgTop, svgTop + modules.length * rowHeight);

	auto timeLabels = svg.g();
	timeLabels.style = "text-anchor: middle; font-size: " ~ text(textSize) ~ "px";
	timeLabels.title() = "(seconds)";
	foreach (x; 0..seconds+1)
		label(timeLabels, center - x*pixelsPerSecond, 0, text(x));

	enum string[Metric.max] METRIC_NAMES  = ["Parse imports", "Import", "Parse", "Compile"];
	enum string[Metric.max] METRIC_COLORS = ["#2222FF", "#00AAAA", "#00CC00", "#FF0000"];

	auto boxes = svg.g();
	auto labels = svg.g();
	labels.style = "font-size: " ~ text(svgTop * 3 / 4) ~ "px";
	foreach (y, m; modules)
	{
		auto rowY = svgTop + y * rowHeight;
		foreach_reverse(metric, time; m.bestTime)
		{
			auto g = boxes.g();
			long relTime = time - (metric ? m.bestTime[metric-1] : 0);
			if (relTime < 0) continue;
			g.title() = format("%s - %5.3f seconds", METRIC_NAMES[metric], relTime * 1.0 / TICKS_PER_SECOND);
			auto w = time * 1.0 / ticksPerPixel;
			shadedRect(g, center - w, rowY, w, rowHeight, METRIC_COLORS[metric]);
		}

		label(labels, textX, rowY, m.name);
	}

	auto legend = svg.g();
	auto legendText = svg.g();
	legend.style = "stroke:black; stroke-width:1";
	legendText.style = "font-size: " ~ text(svgTop * 3 / 4) ~ "px";

	auto legendY = svgTop + (modules.length + 1) * rowHeight;
	label(legendText, textX, legendY, "Legend:");
	legendY += rowHeight;

	foreach (metric; Metric.init..Metric.max)
	{
		shadedRect(legend, center - rowHeight*1/4, legendY + metric * rowHeight + rowHeight*1/4, rowHeight/2, rowHeight/2, METRIC_COLORS[metric]);
		label(legendText, textX, legendY + metric * rowHeight, METRIC_NAMES[metric]);
	}

	fileName.setExtension("svg").write(svg.toString());
}

mixin main!(funopt!makesvg);
