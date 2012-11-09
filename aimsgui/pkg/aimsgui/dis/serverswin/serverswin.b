implement Serverswin;

include "sys.m";
	sys: Sys;
	stderr: ref Sys->FD;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "draw.m";
	draw: Draw;
include "tk.m";
	tk: Tk;
	cmd: import tk;
include "tkclient.m";
	tkclient: Tkclient;

Serverswin: module {
	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

cfg := array[] of {
	"frame .bf",
	"button .bf.update -text {Update} -command {send cmd update}",
	"pack .bf.update -side left -padx 4 -pady 4",
	"frame .t",
	"scrollbar .t.scroll -relief flat -orient vertical -command {.t.t yview}",
	"scrollbar .hscroll -relief flat -orient horizontal -command {.t.t xview}",
	"canvas .t.t -width 1 -height 1 -xscrollcommand {.hscroll set} -yscrollcommand {.t.scroll set}",
	"pack .t.scroll -side right -fill y",
	"pack .t.t -fill both -expand 1",
	"pack .bf -anchor w",
	"pack .t -fill both -expand 1",
	"pack .hscroll -fill x",
	"pack propagate . 0",
};

tktop: ref Tk->Toplevel;
serverid := 0;

badmodule(p: string)
{
	sys->fprint(stderr, "serverswin: cannot load %s: %r\n", p);
	raise "fail:bad module";
}

init(ctxt: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);

	sys->pctl(sys->NEWPGRP, nil);

	bufio = load Bufio Bufio->PATH;
	if (bufio == nil)
		badmodule(Bufio->PATH);

	tkclient = load Tkclient Tkclient->PATH;
	if (tkclient == nil)
		badmodule(Tkclient->PATH);
	tkclient->init();

	tk = load Tk Tk->PATH;
	if (tk == nil)
		badmodule(Tk->PATH);

	if (ctxt == nil) {
		sys->fprint(stderr, "logwindow: nil Draw->Context\n");
		raise "fail:no draw context";
	}

	(top, wmchan) := tkclient->toplevel(ctxt, "", "Servers", Tkclient->Appl);
	if (top == nil) {
		sys->fprint(stderr, "logwindow: couldn't make window\n");
		raise "fail: no window";
	}
	tktop = top;

	tkclient->wmctl(top, "clienticon servers");

	for (c:=0; c<len cfg; c++)
		tk->cmd(top, cfg[c]);
	if ((err := tk->cmd(top, "variable lasterror")) != nil) {
		sys->fprint(stderr, "serverswin: tk error: %s\n", err);
		raise "fail: tk error";
	}

	serverswin(top, wmchan);
}


update_servers()
{
	tk->cmd(tktop, "destroy .servers");
	T("frame .servers");
	T(".t.t create window 0 0 -window .servers -anchor nw");
	buf := bufio->open("/mnt/aims/rotc/serverlist+/v1/list", sys->OREAD);
	if(buf == nil) 
	{
		sys->fprint(stderr, "serverswin: error opening /mnt/aims/rotc/serverlist+/v1/list: %r");
		return;
	}
	for(;;) {
		line := buf.gets('\n');
		if(line == nil)
			return;
		else
			server_add(line);
	}
}

server_add(line: string)
{
	(nil, fields) := sys->tokenize(line, " ");
	playercount := int hd fields; fields = tl fields;
	maxplayers := int hd fields; fields = tl fields;
	minalertedplayers := int hd fields; fields = tl fields;
	optalertedplayers := int hd fields; fields = tl fields;
	interestedplayers := int hd fields; fields = tl fields;
	game := hd fields; fields = tl fields;
	environment := hd fields; fields = tl fields;
	locationcode := hd fields;
	servername := "";
	while(fields != nil)
	{
		servername += hd fields + " ";
		fields = tl fields;
	}
	servername = servername[0:len servername - 2];

	serverid++;

	f := " .servers."+string serverid;
	c := " .servers."+string serverid+".columns";
	s := " .servers."+string serverid+".separator";

	T("frame"+f);
	T("pack"+f+" -side top -fill x");
	T("frame"+c);
	T("pack"+c+" -side top -fill x");
		T("label"+c+".icon -width 26 -bitmap @/icons/game/rotc-eth.bit");
		T("pack"+c+".icon -side left");
		T("label"+c+".playercount -width 2.5w -anchor ne -text "+tk->quote(string playercount));
		T("pack"+c+".playercount -side left");
		T("label"+c+".sep1 -width 1w -text {/}");
		T("pack"+c+".sep1 -side left");
		T("label"+c+".maxplayers -width 2.5w -anchor nw -text "+tk->quote(string maxplayers));
		T("pack"+c+".maxplayers -side left");
		T("label"+c+".sep2 -width 4w -anchor ne -text {+}");
		T("pack"+c+".sep2 -side left");
		T("label"+c+".minalerts -width 2.5w -text "+tk->quote(string minalertedplayers));
		T("pack"+c+".minalerts -side left");
		T("label"+c+".sep3 -width 1w -text {/}");
		T("pack"+c+".sep3 -side left");
		T("label"+c+".optalerts -width 2.5w -text "+tk->quote(string optalertedplayers));
		T("pack"+c+".optalerts -side left");
		T("label"+c+".sep4 -width 1w -text {/}");
		T("pack"+c+".sep4 -side left");
		T("label"+c+".maxalerts -width 2.5w -text "+tk->quote(string interestedplayers));
		T("pack"+c+".maxalerts -side left");
		T("label"+c+".gametype -width 25w -anchor nw -text "+tk->quote(game));
		T("pack"+c+".gametype -side left");
		T("label"+c+".environment -width 15w -anchor nw -text "+tk->quote(environment));
		T("pack"+c+".environment -side left");
		T("label"+c+".servername -anchor nw -text "+tk->quote(servername));
		T("pack"+c+".servername -side left -fill x -expand 1");	
	T("frame"+s+" -height 1 -background black");
	T("pack"+s+" -side top -fill x");	
}


serverswin(top: ref Tk->Toplevel, wmchan: chan of string)
{
	cmd := chan of string;
	tk->namechan(top, cmd, "cmd");
	tkclient->onscreen(top, nil);
	tkclient->startinput(top, "kbd"::"ptr"::nil);
	for (;;) alt {
		s := <-top.ctxt.kbd =>
			tk->keyboard(top, s);
		s := <-top.ctxt.ptr =>
			tk->pointer(top, *s);
		s := <-top.ctxt.ctl or
		s = <-top.wreq or
		s = <-wmchan =>
		tkclient->wmctl(top, s);
	msg := <-cmd =>
		if(msg == "update")
		{
			update_servers();
			x := tk->cmd(tktop, ".servers cget -actwidth");
			y := tk->cmd(tktop, ".servers cget -actheight");
			#sys->fprint(stderr, "%s %s\n", x, y);
			T(".t.t configure -scrollregion "+tk->quote("0 0 "+x+" "+y));
			T("update");
		}
	}
}

T(c: string): string
{
	s := tk->cmd(tktop, c);
	if (s != nil && s[0] == '!')
		sys->fprint(stderr, "serverswin: tk error on %#q: %s\n", c, s);
	return s;
}

