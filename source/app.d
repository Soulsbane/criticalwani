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
	@GetOptOptions("Wether to short by type. Radicals", "s", "sort")
	bool sorted = true;
}

class CriticalWaniApp : Application!Options
{
	override void onCreate()
	{
		startReview();
		saveOptions();
	}

	CriticalItem[] getCriticalItems(const string apiKey)
	{
		// NOTE: The last number is the percentage threshold.
		immutable string apiUrl =  API_URL ~ apiKey ~ "/critical-items/" ~ percentage_;
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

		if(options.getSorted())
		{
			alias criticalItemsSorter = (x, y) => x.type > y.type;
			criticalItems.sort!(criticalItemsSorter);//.release;
		}

		return criticalItems;
	}

	void startReview()
	{
		if(options.hasApiKey() && !isHelpCommand())
		{
			auto criticalItems = getCriticalItems(options.getApiKey());
			writeln("You have ", criticalItems.length, " item(s) to review!");

			foreach(currItem; criticalItems)
			{
				writeln(currItem);
			}
		}
	}

private:
	immutable API_URL = "https://www.wanikani.com/api/user/";
	string percentage_ = "75";
}

void main(string[] arguments)
{
	auto app = new CriticalWaniApp;
	app.create("Raijinsoft", "criticalwani", arguments);
}
