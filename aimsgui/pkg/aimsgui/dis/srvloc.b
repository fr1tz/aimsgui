implement Msrvloc;

include "../module/srvloc.m";

include "sys.m";
	sys: Sys;
include "regex.m";
	regex: Regex;
include "string.m";
	str: String;
include "draw.m";

stderr: ref sys->FD;

badmodule(p: string)
{
	sys->fprint(stderr, "srvloc: cannot load %s: %r\n", p);
	raise "fail:bad module";
}

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);
	if(len argv != 3)
	{
		sys->fprint(stderr, "usage: srvloc code candidate\n");
		raise "fail:args";
	}
	setup(stderr);
	if(check(hd tl argv, hd tl tl argv) == 0)
		raise "fail:no match";
}

setup(_stderr: ref sys->FD)
{
	if(sys == nil) sys = load Sys Sys->PATH;
	if(regex == nil) regex = load Regex Regex->PATH;
	if(regex == nil) badmodule(Regex->PATH);
	if(str == nil) str = load String String->PATH; 
	if(str == nil) badmodule(String->PATH);
	stderr = _stderr;
}

check(locationcode, candidate: string): int
{
	lc := locationcode;
	if(lc == "-a")
		return 1;
	cc := str->tolower(candidate);
	(re,nil) := regex->compile("[a-z]+", 0);
	a  := regex->execute(re, cc);
	if(a == nil)
		return 0;
	(beg,end) := a[0];
	cc = cc[beg:end];
	case lc {
	"eu" => # Europe
		case cc {
		"eu" => return 1;
		"de" => return 1;
		"ch" => return 1;
		"sui" => return 1;
		}
	"us" => # United States
		case cc {
		"us" => return 1;
		}
	"au" => # Australia
		case cc {
		"au" => return 1;
		}
	}
	return 0;
}