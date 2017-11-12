import std.stdio;
import std.json;
import std.exception;
import core.exception : RangeError;
import std.algorithm;
import std.string;
import std.format;
import std.uni;

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
	@GetOptOptions("What percentage and below to use for determining your critical items.", "p", "percent")
	string percentage = "75"; // NOTE: This is the percentage threshold of critical items to fetch.
	@GetOptOptions("Whether to sort by type. Sorted order: Radicals -> Kanji -> Vocab.", "s", "sort")
	bool sorted = true;
}

class CriticalWaniApp : Application!Options
{
	override void onCreate()
	{
		startReview();
		saveOptions();
	}

	bool buildCriticalItemsList(const string apiKey)
	{
		Buffer!ubyte temp;

		immutable string apiUrl =  API_URL ~ apiKey ~ "/critical-items/" ~ options.getPercentage();
		immutable string content = cast(string)getContent(apiUrl)
			.ifThrown!ConnectError(temp)
			.ifThrown!TimeoutException(temp)
			.ifThrown!ErrnoException(temp)
			.ifThrown!RequestException(temp);

		if(content)
		{
			JSONValue[string] document = parseJSON(content).object;
			JSONValue[] requestedInfo = document["requested_information"].array;

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
				//alias criticalItemsSorter = (x, y) => x.type > y.type; // Vocab -> Radical -> Kanji order.
				alias criticalItemsSorter = (x, y) => x.type < y.type; // Kanji -> Radical - Vocab order.
				criticalItems.sort!(criticalItemsSorter);//.release;
			}

			return true;
		}

		return false;
	}

	// TODO: Make use romaji also?
	void checkKana(const string character, const string kana)
	{
		writef("Enter the reading for %s: ", character);
		immutable string answer = readln().strip.chomp;

		if(answer == kana)
		{
			writeln("Correct. Great Job!");
		}
		else
		{
			writefln("%s is the wrong reading! The correct reading is: %s", answer, kana);
		}
	}

	// FIXME: Check for multiple meanings and compare.
	void checkMeaning(const string character, const string meaning)
	{
		writef("Enter the meaning for %s: ", character);
		immutable string answer = readln().strip.chomp.toLower;

		if(answer == meaning.toLower)
		{
			writeln("Correct. Great Job!");
		}
		else
		{
			writefln("%s is the wrong meaning! The correct meaning is: %s", answer, meaning);
		}
	}

	void startReview()
	{
		if(options.hasApiKey() && !isHelpCommand())
		{
			immutable bool success = buildCriticalItemsList(options.getApiKey());

			if(success)
			{
				writeln("You have ", criticalItems.length, " item(s) to review!");

				foreach(currItem; criticalItems)
				{
					checkKana(currItem.character, currItem.kana);
					checkMeaning(currItem.character, currItem.meaning);
				}
			}
			else
			{
				writeln("Failed to download critical items list");
			}
		}
	}

private:
	immutable API_URL = "https://www.wanikani.com/api/user/";
	CriticalItem[] criticalItems;
}

void main(string[] arguments)
{
	auto app = new CriticalWaniApp;
	app.create("Raijinsoft", "criticalwani", arguments);
}
