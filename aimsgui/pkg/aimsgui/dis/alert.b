implement Malert;

include "../module/alert.m";
include "../module/watcher.m";
include "sys.m";
	sys: Sys;
include "string.m";
	str: String;
include "draw.m";

stderr: ref Sys->FD;

ctlpid: int;
heartbeatpid: int;
registrypid: int;
ctlfilepid: int;
watcherpid: int;
ringpid: int;

cout: chan of string;
cctl: chan of (string, chan of string);
cwatcherstate: chan of (int, string);
cregistry: chan of string;

watchertype: string;
watcherargs: list of string;

ctl(cmdline: string): string
{
	cerror := chan of string;
	cctl <-= (cmdline, cerror);
	error := <- cerror;
	return error;
}

ctln(cmdline: string)
{
	cctl <-= (cmdline, nil);
}

ctlfileproc(fio: ref sys->FileIO)
{
	ctlfilepid = sys->pctl(0,nil);
	for (;;) alt {
		(nil, nil, nil, rc) := <-fio.read =>
			if(rc != nil) {
				rc <-= (array of byte "alive", nil);
			}
		(nil, d, nil, wc) := <-fio.write =>
			if (wc != nil) {
				msg := string d;
				error := ctl(msg);
				if(error != nil)
					wc <-= (0, error);
				else
					wc <-= (len d, nil);
			}
	}
}

ctlproc()
{
	ctlpid = sys->pctl(0,nil);
	for(;;) alt {
		(cmdline, cerror) := <- cctl =>
			fields := str->unquoted(cmdline);
			if(hd fields == "exit")
			{
				if(cerror != nil)
					cerror <-= nil;
				postnote(heartbeatpid, "kill");
				postnote(registrypid, "kill");
				postnote(ctlfilepid, "kill");
				postnote(watcherpid, "killgrp");
				postnote(ringpid, "kill");
				cout <-= "exit";
				cout <-= nil;
				exit;
			}
			else if(hd fields == "on")
			{
				wtype := hd tl fields;
				wargs := tl tl fields;
				watcher_spawn(wtype, wargs);
				if(cerror != nil)
					cerror <-= nil;
			}
			else if(hd fields == "off")
			{
				watcher_kill();
				status("off");
				if(cerror != nil)
					cerror <-= nil;
			}
			else if(hd fields == "pname")
			{
				cregistry <-= "user " + hd tl fields;
				cout <-= "pname " + hd tl fields;
				if(cerror != nil)
					cerror <-= nil;
			}
			else
			{
				if(cerror != nil)
					cerror <-= "invalid ctl message";
			}

		(state, error) := <- cwatcherstate =>
			if(state == -1)
			{
				sys->fprint(stderr, "alert: watcher error: %s\n", error);
				watcher_kill();
				status("off");
			}
			else if(state == 0)
			{
				ringproc_kill();
				status("running " + watchertype + " " + str->quoted(watcherargs));
			}
			else if(state == 1)
			{
				ringproc_spawn();
				status("ringing " + watchertype + " " + str->quoted(watcherargs));
			}
	}
}

die(error: string)
{
	if(error != nil)
		sys->fprint(stderr, "alert: %s; exiting...\n", error);
	cctl <-= ("exit", nil);
}

heartbeatproc(cmsg: chan of string)
{
	heartbeatpid = sys->pctl(0,nil);
	for(;;) {
		sys->sleep(10 * 1000);
		cmsg <-= "heartbeat";
	}
}

init(nil: ref Draw->Context, nil: list of string)
{
	if(sys == nil) sys = load Sys Sys->PATH;
	if(str == nil) str = load String String->PATH;
	sc := chan of string;
	spawn run(sc);
	for(;;) {
		status := <-sc;
		if(status == nil)
			exit;
		else
		{
			{
				if(sys->print("%s\n", status) < 0)
					die(sys->sprint("sys->sprint() failed: %r"));
			} exception e {
				"write on closed pipe" => die(nil);
			}
		}
	}
}

postnote(pid: int, note: string): int
{
	if(pid == 0)
		return 0;
	fd := sys->open("/prog/" + string pid + "/ctl", sys->OWRITE);
	#fd := sys->open("#p/" + string pid + "/ctl", sys->OWRITE);
	if(fd == nil)
		return -1;
	sys->fprint(fd, "%s", note);
	fd = nil;
	return 0;
}

readfile(filename: string): string
{
	fd := sys->open(filename, Sys->OREAD);
	if(fd == nil)
	{
		sys->fprint(stderr, "alert: can't open %s: %r\n", filename);
		return nil;
	}
	(ok, stat) := sys->fstat(fd);
	if(ok == -1)
	{
		sys->fprint(stderr, "alert: can't fstat %s: %r\n", filename);
		return nil;
	}
	buf := array[int stat.length] of byte;
	n := sys->read(fd, buf, len buf);
	if(n < 0)
	{
		sys->fprint(stderr, "alert: can't read %s: %r\n", filename);
		return nil;
	}
	return string buf[0:n];
}

registryproc(cmsg: chan of string)
{
	registrypid = sys->pctl(0,nil);
	fd := sys->open("/mnt/aims/alertlist/v1/enter", sys->ORDWR);
	if(fd == nil) 
		die(sys->sprint("error opening alert registry: %r"));
	for(;;) {
		msg := <- cmsg;
		msg += "\n";
		if(sys->write(fd, array of byte msg, len msg) != len msg)
			die(sys->sprint("error writing msg to alert registry: %r"));
		ack := array[3] of byte;
		if(sys->read(fd, ack, len ack) != len ack)	
			die(sys->sprint("error reading ack from alert registry: %r"));
		if(string ack != "ok\n")
			die(sys->sprint("expected 'ok' from alert registry, got: %s", string ack));
	}
}

ringproc(cmsg: chan of string)
{
	ringpid = sys->pctl(0,nil);
	for(;;) {
		cmsg <-= "ring!";
		sys->sleep(1 * 1000);
	}
}

ringproc_kill()
{
	if(ringpid != 0)
		postnote(ringpid, "kill");
	ringpid = 0;
}

ringproc_spawn()
{
	spawn ringproc(cout);
}

run(sc: chan of string)
{
	if(sys == nil) sys = load Sys Sys->PATH;
	if(str == nil) str = load String String->PATH;
	stderr = sys->fildes(2);
	ctlfile := "alert." + string sys->pctl(0,nil) + ".ctl"; 
	fio := sys->file2chan("/chan", ctlfile);
	if(fio == nil) {
		sys->fprint(stderr, "alert: file2chan failed: %r\n");
		return;
	}
	ctlpid = 0;
	heartbeatpid = 0;
	registrypid = 0;
	ctlfilepid = 0;
	watcherpid = 0;
	ringpid = 0;
	cout = sc;
	cctl = chan of (string, chan of string);
	cwatcherstate = chan of (int, string);
	cregistry = chan of string;
	spawn heartbeatproc(cregistry);
	spawn registryproc(cregistry);
	spawn ctlfileproc(fio);
	spawn ctlproc();
	playername := readfile("/tmp/playername");
	if(playername != nil)
		cregistry <-= "user "+playername;
	cout <-= "ctl /chan/" + ctlfile;
}

status(msg: string)
{
	cregistry <-= msg;
	cout <-= msg;
}

watcher_kill()
{
	ringproc_kill();
	if(watcherpid != 0)
		postnote(watcherpid, "killgrp");
	watcherpid = 0;
	watchertype = nil;
	watcherargs = nil;	
}

watcher_spawn(wtype: string, wargs: list of string)
{
	watcher_kill();
	watchertype = wtype;
	watcherargs = wargs;
	spawn watcherproc(wtype, wargs);
}

watcherproc(wtype: string, wargs: list of string)
{
	watcherpid = sys->pctl(sys->NEWPGRP, nil);
	watcher := load Mwatcher "/dis/aimsgui/watcher/" + wtype + ".dis";
	if(watcher != nil)
		watcher->run(wargs, cwatcherstate);
	cwatcherstate <-= (-1, "watcher terminated unexpectedly");
}

