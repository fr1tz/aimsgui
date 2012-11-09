implement Msoundplayer;

include "../../module/soundplayer.m";
include "sys.m";
	sys: Sys;
	FD:	import sys;
include "draw.m";

prog:	con "soundplayer/audio3";
Magic:	con "rate";
data:	con "/dev/audio";
ctl:	con "/dev/audioctl";
buffz:	con Sys->ATOMICIO;

stderr: ref Sys->FD;

init(nil: ref Draw->Context, argv: list of string)
{
	if(sys == nil) sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);
	if(len argv != 2) {
		sys->fprint(stderr, "usage: %s sound\n", prog);
		raise "fail:args";		
	}
	play(hd tl argv);
}

play(sound: string)
{
	f := "/aimsgui/misc/sound/" + sound + ".iaf";
	buff := array[buffz] of byte;
	inf := sys->open(f, Sys->OREAD);
	if (inf == nil) {
		sys->fprint(stderr, "%s: could not open %s: %r\n", prog, f);
		return;
	}
	n := sys->read(inf, buff, buffz);
	if (n < 0) {
		sys->fprint(stderr, "%s: could not read %s: %r\n", prog, f);
		return;
	}
	if (n < 10 || string buff[0:4] != Magic) {
		sys->fprint(stderr, "%s: %s: not an audio file\n", prog, f);
		return;
	}
	i := 0;
	for (;;) {
		if (i == n) {
			sys->fprint(stderr, "%s: %s: bad header\n", prog, f);
			return;
		}
		if (buff[i] == byte '\n') {
			i++;
			if (i == n) {
				sys->fprint(stderr, "%s: %s: bad header\n", prog, f);
				return;
			}
			if (buff[i] == byte '\n') {
				i++;
				if ((i % 4) != 0) {
					sys->fprint(stderr, "%s: %s: unpadded header\n", prog, f);
					return;
				}
				break;
			}
		}
		else
			i++;
	}
	df := sys->open(data, Sys->OWRITE);
	if (df == nil) {
		sys->fprint(stderr, "%s: could not open %s: %r\n", prog, data);
		return;
	}
	cf := sys->open(ctl, Sys->OWRITE);
	if (cf == nil) {
		sys->fprint(stderr, "%s: could not open %s: %r\n", prog, ctl);
		return;
	}
	if (sys->write(cf, buff, i - 1) < 0) {
		sys->fprint(stderr, "%s: could not write %s: %r\n", prog, ctl);
		return;
	}
	if (n > i && sys->write(df, buff[i:n], n - i) < 0) {
		sys->fprint(stderr, "%s: could not write %s: %r\n", prog, data);
		return;
	}
	if (sys->stream(inf, df, Sys->ATOMICIO) < 0) {
		sys->fprint(stderr, "%s: could not stream %s: %r\n", prog, data);
		return;
	}
}

setup(argv: list of string, errors: ref sys->FD)
{
	if(sys == nil) sys = load Sys Sys->PATH;
	stderr = errors;
}
