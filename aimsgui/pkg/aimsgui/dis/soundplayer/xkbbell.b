implement Msoundplayer;

include "../../module/soundplayer.m";
include "sys.m";
	sys: Sys;
	FD:	import sys;
include "sh.m";
	sh: Sh;
include "draw.m";

prog:	con "soundplayer/xkbbell";
stderr: ref Sys->FD;

badmodule(p: string)
{
	sys->fprint(stderr, "%s: cannot load %s: %r\n", prog, p);
	raise "fail:bad module";
}

init(nil: ref Draw->Context, argv: list of string)
{
	if(sys == nil) sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);
	if(len argv != 2) {
		sys->fprint(stderr, "usage: %s file\n", prog);
		raise "fail:args";		
	}
	setup(nil, stderr);
	play(hd tl argv);
}

play(sound: string)
{
	(nfields, fields) := sys->tokenize(sound, ".");
	if(hd fields == "alert")
		sh->system(nil, "os xkbbell </dev/null >/dev/null >[2]/dev/null");
}

setup(argv: list of string, errors: ref sys->FD)
{
	if(sys == nil) sys = load Sys Sys->PATH;
	if(sh == nil) sh = load Sh Sh->PATH;
	if(sh == nil) badmodule(Sh->PATH);
	stderr = errors;
}
