import std.stdio;
import std.json;
import std.exception;
import core.exception : RangeError;
import std.algorithm;
import std.string;
import std.format;
import std.uni;
import std.array;

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
	@GetOptOptions("Always answer the meaning right after the reading.", "c", "consecutive")
	bool consecutiveOrder = false;
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
		immutable string answer = readln().strip.chomp.toLower;
		bool correctAnswer;

		foreach(value; kana.toLower.split(","))
		{
			if(answer == value.strip.chomp)
			{
				writeln("Correct. Great Job!");
				correctAnswer = true;
				break;
			}
		}

		if(!correctAnswer)
		{
			writefln("%s is the wrong reading! The correct reading is: %s", answer, kana);
		}
	}

	bool checkMeaningAnswer(const string answer, const string meaning)
	{
		immutable string correctAnswer = meaning.strip.chomp;
		immutable size_t distance = 3;

		// If the meaning is a small word we need to check for an exact match since misspellings in this case can change the meaning
		if(correctAnswer.length < distance)
		{
			if(answer == correctAnswer)
			{
				return true;
			}

			return false;
		}
		else
		{
			if(levenshteinDistance(answer, correctAnswer) < distance)
			{
				return true;
			}

			return false;
		}
	}

	void checkMeaning(const string character, const string meaning)
	{
		writef("Enter the meaning for %s: ", character);
		immutable string answer = readln().strip.chomp.toLower;
		bool correctAnswer;

		foreach(value; meaning.toLower.split(","))
		{
			if(checkMeaningAnswer(answer, value))
			{
				writeln("Correct. Great Job!");
				correctAnswer = true;
				break;
			}
		}

		if(!correctAnswer)
		{
			writefln("%s is the wrong meaning! The correct meaning is: %s", answer, meaning);
		}
	}

	void reviewInConsecutiveOrder()
	{
		foreach(currItem; criticalItems)
		{
			checkKana(currItem.character, currItem.kana);
			checkMeaning(currItem.character, currItem.meaning);
		}
	}

	void reviewInSeparateOrder()
	{
		foreach(currItem; criticalItems)
		{
			checkKana(currItem.character, currItem.kana);
		}

		foreach(currItem; criticalItems)
		{
			checkMeaning(currItem.character, currItem.meaning);
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

				if(options.getConsecutiveOrder)
				{
					reviewInConsecutiveOrder();
				}
				else
				{
					reviewInSeparateOrder();
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
