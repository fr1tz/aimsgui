implement Aimsgametype;

include "sys.m";
	sys: Sys;
include "regex.m";
	regex: Regex;
include "string.m";
	str: String;
include "draw.m";

include "../module/gametype.m";

stderr: ref sys->FD;

badmodule(p: string)
{
	sys->fprint(stderr, "gametype: cannot load %s: %r\n", p);
	raise "fail:bad module";
}

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);
	if(len argv != 3)
	{
		sys->fprint(stderr, "usage: gametype gamecode candidate\n");
		raise "fail:args";
	}
	setup(stderr);
	if(match(hd tl argv, hd tl tl argv) == 0)
		raise "fail:no match";
}

setup(_stderr: ref sys->FD)
{
	stderr = _stderr;
	if(sys == nil) sys = load Sys Sys->PATH;
	if(regex == nil) regex = load Regex Regex->PATH;
	if(regex == nil) badmodule(Regex->PATH);
	if(str == nil) str = load String String->PATH; 
	if(str == nil) badmodule(String->PATH);
}

match(gamecode, candidate: string): int
{
	if(gamecode == nil || candidate == nil)
		return 0;
	if(len gamecode >= 8 && gamecode[0:8] == "rotc-eth")
	{
		(re,nil) := regex->compile("ROTC:ETH", 0);
		a  := regex->execute(re, candidate);
		if(a == nil)
			return 0;
		if(gamecode == "rotc-eth")
		{
			return 1;
		}
		else if(gamecode == "rotc-eth-pure")
		{
			(re,nil) = regex->compile("\\[", 0);
			a  = regex->execute(re, candidate);
			if(a == nil)
				return 1;
		}
		else if(gamecode == "rotc-eth-quickdeath")
		{
			(re,nil) = regex->compile("QUICKDEATH", 0);
			a  = regex->execute(re, candidate);
			if(a != nil)
				return 1;
		}
	}
	return 0;
}
