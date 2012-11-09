implement Sound_daemon;

include "sys.m";
	sys: Sys;
include "../module/soundplayer.m";
	sp: Msoundplayer;
include "draw.m";

prog: con "sound-daemon";

stderr: ref Sys->FD;

soundlistpid: int;
filesrvpid: int;
playerpid: int;

csoundlistadd: chan of string;
csoundlistnext: chan of chan of string;

Sound_daemon: module {
	init: fn(nil: ref Draw->Context, argv: list of string);
};

badmodule(p: string)
{
	sys->fprint(stderr, "%s: cannot load %s: %r\n", prog, p);
	raise "fail:bad module";
}

filesrvproc(fio: ref sys->FileIO, pidchan: chan of int)
{
	pidchan <-= sys->pctl(0,nil);
	for (;;) alt {
		(offset, count, nil, rc) := <-fio.read =>
			if(rc != nil) {
				rc <-= (nil, prog + ": read not supported");
			}
		(offset, d, nil, wc) := <-fio.write =>
			if (wc != nil) {
				wc <-= (len d, nil);
				csoundlistadd <-= string d;
			}
	}
}

init(nil: ref Draw->Context, argv: list of string)
{
	if(sys == nil) sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);
	if(len argv != 2) {
		sys->fprint(stderr, "usage: %s sound_player\n", prog);
		raise "fail:args";		
	}
	path := "/dis/aimsgui/soundplayer/" + hd tl argv + ".dis";
	sp = load Msoundplayer path;
	if(sp == nil) {
		path = "/dis/aimsgui/soundplayer/oscmd.dis";
		sp = load Msoundplayer path;
		if(sp == nil) badmodule(path);
	}
	sp->setup(tl argv, stderr);
	fio := sys->file2chan("/chan", "sound");
	if (fio == nil) {
		sys->fprint(stderr, "%s: file2chan failed: %r\n", prog);
		raise "fail:fail2chan";
	}
	csoundlistadd = chan of string;
	csoundlistnext = chan of chan of string;
	pidchan := chan of int;
	spawn soundlistproc(pidchan); soundlistpid = <-pidchan;
	spawn filesrvproc(fio, pidchan); filesrvpid = <-pidchan;
	spawn playerproc(pidchan); playerpid = <-pidchan;
}

playerproc(pidchan: chan of int)
{
	pidchan <-= sys->pctl(0,nil);
	for(;;)
	{
		c := chan of string;		
		csoundlistnext <-= c;
		s := <-c;
		sp->play(s);
	}
}

soundlistproc(pidchan: chan of int)
{
	pid := sys->pctl(0,nil);
	pidchan <-= pid;
	soundlist: list of string;
	lastadded := "";
	drainer: chan of string;
	for(;;) alt {
		s := <-csoundlistadd =>
			if(s != lastadded)
			{
				if(drainer != nil)
				{
					drainer <-= s;
					drainer = nil;
				}
				else
				{
					soundlist = s::soundlist;
				}
				lastadded = s;
			}
		c := <-csoundlistnext =>
			if(soundlist != nil)
			{
				c <-= hd soundlist;
				soundlist = tl soundlist;
			}
			else
			{
				# soundlist empty
				drainer = c;
				lastadded = nil;
			}
	}
}



