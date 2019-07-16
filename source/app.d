import std.stdio;
import std.datetime.systime : Clock;
import std.process : execute;
import std.traits : isMutable;
import std.typecons : Flag, No, Yes;
import std.traits : isMutable, isSomeString;
import std.range : ElementType, ElementEncodingType;

version(Windows) {}
else
{
	static assert(0, "This only works on Windows as of yet");

}

long[string] pidTime;

enum sleepTime = 10;  // seconds
enum timeoutTime = 60;  // seconds


void main(string[] args)
{
	if (args.length != 2)
	{
		writeln("Usage: %s [process name]", args[0]);
		return;
	}

	immutable filename = args[1];

	while (true)
	{
		updatePidTable(filename);

		immutable now = Clock.currTime.toUnixTime;
		string[] toRemove;

		foreach (pid, timestamp; pidTime)
		{
			if ((now - timestamp) > timeoutTime)
			{
				writeln("Killing ", pid);
				immutable taskkill = execute("taskkill " ~ pid);
				if (taskkill.status != 0) writeln("NON-ZERO RETURN");
				toRemove ~= pid;
			}
		}

		foreach (pid; toRemove)
		{
			pidTime.remove(pid);
		}

		import core.thread : Thread;
		import core.time : seconds;

		Thread.sleep(sleepTime.seconds);
	}
}


void updatePidTable(const string filename)
{
	import std.algorithm.iteration : splitter;
	import std.algorithm.searching : startsWith;
	import std.conv : to;
	import std.string : stripLeft;

	immutable tasklist = execute("tasklist /FI IMAGENAME eq " ~ filename);

	auto pidList = tasklist.output.splitter("\n");
	while (!pidList.front.startsWith(filename)) pidList.popFront();

	foreach (immutable pidLine; pidList)
	{
		string line = pidLine;  // mutable
		immutable cmd = line.nom(' ');
		line = line.stripLeft();
		immutable pid = line.nom(' ');

		if (pid !in pidTime)
		{
			writeln("Saw new pid ", pid);
			pidTime[pid] = Clock.currTime.toUnixTime;
		}
	}
}


pragma(inline)
T nom(Flag!"decode" decode = No.decode, T, C)(auto ref T line, const C separator,
    const string callingFile = __FILE__, const size_t callingLine = __LINE__) pure
if (isMutable!T && isSomeString!T && (is(C : T) || is(C : ElementType!T) || is(C : ElementEncodingType!T)))
{
    static if (decode || is(T : dstring) || is(T : wstring))
    {
        import std.string : indexOf;
        // dstring and wstring only work with indexOf, not countUntil
        immutable index = line.indexOf(separator);
    }
    else
    {
        // Only do this if we know it's not user text
        import std.algorithm.searching : countUntil;
        import std.string : representation;

        static if (isSomeString!C)
        {
            immutable index = line.representation.countUntil(separator.representation);
        }
        else
        {
            immutable index = line.representation.countUntil(cast(ubyte)separator);
        }
    }

    if (index == -1)
    {
        import std.format : format;
        throw new Exception(`Tried to nom too much: "%s" with "%s"`
            .format(line, separator), callingFile, callingLine);
    }

    static if (isSomeString!C)
    {
        immutable separatorLength = separator.length;
    }
    else
    {
        enum separatorLength = 1;
    }

    static if (__traits(isRef, line))
    {
        scope(exit) line = line[(index+separatorLength)..$];
    }

    return line[0..index];
}
