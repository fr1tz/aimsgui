implement Msoundplayer;

include "../../module/soundplayer.m";
include "env.m";
	env: Env;
include "sys.m";
	sys: Sys;
	FD:	import sys;
include "sh.m";
	sh: Sh;
include "draw.m";

prog:	con "soundplayer/oscmd";
stderr: ref Sys->FD;
oscmd: string;

badmodule(p: string)
{
	sys->fprint(stderr, "%s: cannot load %s: %r\n", prog, p);
	raise "fail:bad module";
}

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);
	if(len argv != 3) {
		sys->fprint(stderr, "usage: %s oscmd file\n", prog);
		raise "fail:args";		
	}
	setup(tl argv, stderr);
	play(hd tl tl argv);
}

play(sound: string)
{
	d := env->getenv("emuroot")+"/../aimsgui/audio/aimsgui";
	f := sound + ".wav";
	sh->system(nil, "os -d "+d+" "+oscmd+" "+f+" </dev/null >[2=1] >/dev/null");
}

setup(argv: list of string, errors: ref sys->FD)
{
	if(sys == nil) sys = load Sys Sys->PATH;
	if(sh == nil) sh = load Sh Sh->PATH;
	if(sh == nil) badmodule(Sh->PATH);
	if(env == nil) env = load Env Env->PATH;
	if(env == nil) badmodule(Env->PATH);
	stderr = errors;
	oscmd = hd argv;
}
