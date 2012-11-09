include "../../module/watcher.m";

include "sys.m";
	sys: Sys;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "regex.m";
	regex: Regex;
include "string.m";
	str: String;
include "draw.m";
include "../../module/srvloc.m";
	srvloc: Msrvloc;

state: int;
statechan: chan of (int, string);
location: string;
playercount: int;

error(error: string)
{
	statechan <-= (-1, error);
}

matches_location(line: string): int
{
	(nil, fields) := sys->tokenize(line, " ");
	if(int hd fields >= playercount)
		return 1;
	return 0;
}

init(nil: ref Draw->Context, argv: list of string)
{
	if(sys == nil) sys = load Sys Sys->PATH;
	stderr := sys->fildes(2);
	sc := chan of (int, string);
	spawn run(tl argv, sc);
	for(;;) {
		(s, err) := <-sc;
		if(s == -1)
		{
			sys->fprint(stderr, "%s: %s\n", WATCHERTYPE, err);
			exit;
		}
		else if(s == 0)
			sys->print("running\n");
		else if(s == 1)
			sys->print("ringing\n");
	}	
}

run(argv: list of string, sc: chan of (int, string))
{	
	if(sys == nil) sys = load Sys Sys->PATH;
	if(bufio == nil) bufio = load Bufio Bufio->PATH;
	if(regex == nil) regex = load Regex Regex->PATH;
	if(str == nil) str = load String String->PATH;
	if(srvloc == nil) srvloc = load Msrvloc Msrvloc->PATH;
	srvloc->setup(sys->fildes(2));
	state = -1;
	statechan = sc;
	err := parse_args(argv);
	if(err != nil) {
		error(err);
		return;	
	}
	set_state(0);
	while(1) 
	{
		newstate := 0;
		buf := bufio->open("/mnt/aims/rotc/serverlist/v1/wait", sys->OREAD);
		if(buf == nil) 
			return error(sys->sprint("error opening /mnt/aims/rotc/serverlist/v1/wait: %r"));
		for(;;) {
			line := buf.gets('\n');
			if(line == nil)
				break;
			#sys->print("checking line: %s\n", line);
			(nil, fields) := sys->tokenize(line, " ");
			candidate := hd tl tl tl tl fields;
			#sys->print("srvloc: %s\n", srvloc);
			if(int hd fields >= playercount)
				if(srvloc->check(location, candidate) == 1)
					if(check_server(fields) == 1)
						newstate = 1;
		}
		set_state(newstate);
	}
}

parse_args(argv: list of string): string
{
	if(len argv != 2)
		return "usage: " + WATCHERTYPE + " server_location player_count";
	location = hd argv;
	playercount = int hd tl argv;
	return nil;
}

set_state(newstate: int)
{
	if(newstate != state)
	{
		state = newstate;
		statechan <-= (state, nil);
	}
}

