import std.stdio;
import std.json;
import std.exception;
import core.exception : RangeError;
import std.algorithm;

import requests;

struct CriticalItem
{
	string type;
	string character;
	string kana;
	string meaning;
	long level;
	string percentage;
	bool passed;
}

CriticalItem[] getCriticalItems(const bool sorted = true)
{

	// NOTE: The last number is the percentage threshold.
	string content = cast(string)getContent("https://www.wanikani.com/api/user/696c570e8a176bd18779361177455993/critical-items/75");
	JSONValue[string] document = parseJSON(content).object;
	JSONValue[] requestedInfo = document["requested_information"].array;
	CriticalItem[] criticalItems;

	foreach(info; requestedInfo)
	{
		CriticalItem criticalItem;
		JSONValue[string] criticalItemObject = info.object;

		criticalItem.meaning = criticalItemObject["meaning"].str;
		criticalItem.type = criticalItemObject["type"].str;
		criticalItem.level = criticalItemObject["level"].integer;
		criticalItem.percentage = criticalItemObject["percentage"].str;
		criticalItem.character = criticalItemObject["character"].str.ifThrown!JSONException("No Character");
		criticalItem.kana = criticalItemObject["kana"].str.ifThrown!RangeError("No Kana"); // Kana field can be missing.

		criticalItems ~= criticalItem;
	}

	if(sorted)
	{
		alias criticalItemsSorter = (x, y) => x.type > y.type;
		criticalItems.sort!(criticalItemsSorter);//.release;
	}

	return criticalItems;
}

void main(string[] arguments)
{
	auto criticalItems = getCriticalItems();

	writeln("You have ", criticalItems.length, " item(s) to review!");

	foreach(currItem; criticalItems)
	{
		writeln(currItem);
	}
}
