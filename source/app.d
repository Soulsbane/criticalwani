import std.stdio;
import std.json;
import std.exception;
import core.exception : RangeError;
import std.algorithm;

import requests;
import dapplicationbase;

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

struct Options
{
	@GetOptOptions("Set wanikani API key", "k", "key")
	string apiKey;
}

class CriticalWaniApp : Application!Options
{
	CriticalItem[] getCriticalItems(const string apiKey, const bool sorted = true)
	{
		// NOTE: The last number is the percentage threshold.
		immutable string apiUrl = "https://www.wanikani.com/api/user/" ~ apiKey ~ "/critical-items/75";
		string content = cast(string)getContent(apiUrl);
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
}

void main(string[] arguments)
{
	auto app = new CriticalWaniApp;

	app.create("Raijinsoft", "criticalwani");
	app.handleCmdLineArguments(arguments);

	if(app.options.hasApiKey() && !app.isHelpCommand())
	{
		auto criticalItems = app.getCriticalItems(app.options.getApiKey());
		writeln("You have ", criticalItems.length, " item(s) to review!");

		foreach(currItem; criticalItems)
		{
			writeln(currItem);
		}
	}

	app.saveOptions();
}
