implement Tabswintoolbar;

include "sys.m";
	sys: Sys;
include "env.m";
	env: Env;
include "draw.m";
	draw: Draw;
	Screen, Display, Image, Rect, Point, Wmcontext, Pointer: import draw;
include "tk.m";
	tk: Tk;
include "tkclient.m";
	tkclient: Tkclient;
include "sh.m";
	shell: Sh;
	Listnode, Context: import shell;
include "string.m";
	str: String;
include "arg.m";

myselfbuiltin: Shellbuiltin;

Tabswintoolbar: module 
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
	initbuiltin: fn(c: ref Context, sh: Sh): string;
	runbuiltin: fn(c: ref Context, sh: Sh,
			cmd: list of ref Listnode, last: int): string;
	runsbuiltin: fn(c: ref Context, sh: Sh,
			cmd: list of ref Listnode): list of ref Listnode;
	whatis: fn(c: ref Sh->Context, sh: Sh, name: string, wtype: int): string;
	getself: fn(): Shellbuiltin;
};

MAXCONSOLELINES:	con 1024;

# execute this if no menu items have been created
# by the init script.
defaultscript :=
	"{menu shell " +
		"{{autoload=std; load $autoload; pctl newpgrp; wm/sh}&}}";

tbtop: ref Tk->Toplevel;
screenr: Rect;
kbdfocus: string;

badmodule(p: string)
{
	sys->fprint(stderr(), "toolbar: cannot load %s: %r\n", p);
	raise "fail:bad module";
}

init(ctxt: ref Draw->Context, argv: list of string)
{
	sys  = load Sys Sys->PATH;
	env = load Env Env->PATH;
	if(env == nil)
		badmodule(Env->PATH);
	draw = load Draw Draw->PATH;
	if(draw == nil)
		badmodule(Draw->PATH);
	tk   = load Tk Tk->PATH;
	if(tk == nil)
		badmodule(Tk->PATH);

	str = load String String->PATH;
	if(str == nil)
		badmodule(String->PATH);

	tkclient = load Tkclient Tkclient->PATH;
	if(tkclient == nil)
		badmodule(Tkclient->PATH);
	tkclient->init();

	shell = load Sh Sh->PATH;
	if (shell == nil)
		badmodule(Sh->PATH);
	arg := load Arg Arg->PATH;
	if (arg == nil)
		badmodule(Arg->PATH);

	myselfbuiltin = load Shellbuiltin "$self";
	if (myselfbuiltin == nil)
		badmodule("$self(Shellbuiltin)");

	sys->pctl(Sys->NEWPGRP|Sys->FORKNS, nil);

	sys->bind("#p", "/prog", sys->MREPL);
	sys->bind("#s", "/chan", sys->MBEFORE);

	arg->init(argv);
	arg->setusage("toolbar [-s]");
	startmenu := 1;
	while((c := arg->opt()) != 0){
		case c {
		's' =>
			startmenu = 0;
		* =>
			arg->usage();
		}
	}
	argv = arg->argv();
	arg = nil;

	if (ctxt == nil){
		sys->fprint(sys->fildes(2), "toolbar: must run under a window manager\n");
		raise "fail:no wm";
	}

	exec   := chan of string;
	select := chan of string;
	close  := chan of string;

	tbtop = toolbar(ctxt, startmenu, exec, select, close);
	tkclient->startinput(tbtop, "ptr" :: "control" :: nil);
	layout(tbtop);

	shctxt := Context.new(ctxt);
	shctxt.addmodule("wm", myselfbuiltin);

	snarfIO := sys->file2chan("/chan", "snarf");
	if(snarfIO == nil)
		fatal(sys->sprint("cannot make /chan/snarf: %r"));
	sync := chan of string;
#	spawn consoleproc(ctxt, sync);
#	if ((err := <-sync) != nil)
#		fatal(err);

	setupfinished := chan of int;
	donesetup := 0;
	spawn setup(shctxt, setupfinished);

	snarf: array of byte;
#	write("/prog/"+string sys->pctl(0, nil)+"/ctl", "restricted"); # for testing
	for(;;) alt{
	s := <-tbtop.ctxt.kbd =>
		tk->keyboard(tbtop, c);
	m := <-tbtop.ctxt.ptr =>
		tk->pointer(tbtop, *m);
	s := <-tbtop.ctxt.ctl or
	s = <-tbtop.wreq =>
		wmctl(tbtop, s);
	s := <-exec =>
		# guard against parallel access to the shctxt environment
		if (donesetup){
			{
 				shctxt.run(ref Listnode(nil, s) :: nil, 0);
			} exception e {"fail:*" =>;}
		}
	s := <-select =>
		client_focus(s);
	s := <-close =>
		tkclient->wmctl(tbtop, sys->sprint("ctl %q exit", s));
	(off, data, fid, wc) := <-snarfIO.write =>
		if(wc == nil)
			break;
		if (off == 0)			# write at zero truncates
			snarf = data;
		else {
			if (off + len data > len snarf) {
				nsnarf := array[off + len data] of byte;
				nsnarf[0:] = snarf;
				snarf = nsnarf;
			}
			snarf[off:] = data;
		}
		wc <-= (len data, "");
	(off, nbytes, nil, rc) := <-snarfIO.read =>
		if(rc == nil)
			break;
		if (off >= len snarf) {
			rc <-= (nil, "");		# XXX alt
			break;
		}
		e := off + nbytes;
		if (e > len snarf)
			e = len snarf;
		rc <-= (snarf[off:e], "");	# XXX alt
	donesetup = <-setupfinished =>
		;	
	}
}

wmctl(top: ref Tk->Toplevel, c: string)
{
	args := str->unquoted(c);
	if(args == nil)
		return;
	n := len args;

	case hd args{
	"request" =>
		# request clientid args...
		if(n < 3)
			return;
		args = tl args;
		clientid := hd args;
		args = tl args;
		err := handlerequest(clientid, args);
		if(err != nil)
			sys->fprint(sys->fildes(2), "toolbar: bad wmctl request %#q: %s\n", c, err);
	"newclient" =>
		# newclient id
		client_new(hd tl args);
	"delclient" =>
		# delclient id
		client_del(hd tl args);
	"kbdfocuschange" =>
		# kbdfocuschange client_id
		client_kbdfocuschange(hd tl args);
	"rect" =>
		tkclient->wmctl(top, c);
		layout(top);
	* =>
		tkclient->wmctl(top, c);
	}
}

handlerequest(clientid: string, args: list of string): string
{
	n := len args;
	case hd args {
	"task" =>
		# task name
		if(n != 2)
			return "no task label given";
		client_iconify(clientid, hd tl args);
	"untask" or
	"unhide" =>
		client_focus(clientid);
	"clientname" =>
		# clientname name
		if(n < 2)
			return "no label given";
		label := "";
		words := tl args;
		while(words != nil)
		{
			label = label + hd words;
			words = tl words;
			if(words != nil)
				label = label + " ";
		}
		client_name(clientid, label);
	"clienticon" =>
		# clienticon icon
		if(n < 2)
			return "no icon given";
		client_icon(clientid, hd tl args);
	* =>
		return "unknown request";
	}
	return nil;
}

client_focus(id: string)
{
	if(tk->cmd(tbtop, "winfo class .toolbar."+id)[0] == '!')
		return;
	if(tk->cmd(tbtop, ".toolbar."+id+" cget -relief") == "sunken")
		tkclient->wmctl(tbtop, sys->sprint("ctl %q untask", id));
	else
		tkclient->wmctl(tbtop, sys->sprint("ctl %q raise", id));
	tkclient->wmctl(tbtop, sys->sprint("ctl %q kbdfocus 1", id));
	cmd(tbtop, ".toolbar." +id+" configure -relief raised");
	cmd(tbtop, "update");
}

client_icon(id, icon: string)
{
	#sys->fprint(sys->fildes(2), "tabswin/toolbar: client_icon(): %s %s\n", id, icon);
 	#if(tk->cmd(tbtop, "image type "+icon)[0] == '!')
	#{
	#}
	cmd(tbtop, ".toolbar." +id+".icon configure -bitmap @/icons/aimsgui/"+icon+".bit");
	cmd(tbtop, "update");
}

client_iconify(id, label: string)
{
	label = condenselabel(label);
	cmd(tbtop, ".toolbar." +id+" configure -relief sunken");
	cmd(tbtop, ".toolbar." +id+".text configure -text '" + label);
	cmd(tbtop, "update");
}

client_kbdfocuschange(id: string)
{
	if(kbdfocus != nil)
	{
		c := cmd(tbtop, ". cget -background");
		cmd(tbtop, ".toolbar."+kbdfocus+" configure -background "+c);
		cmd(tbtop, ".toolbar."+kbdfocus+".icon configure -background "+c);
		cmd(tbtop, ".toolbar."+kbdfocus+".text configure -background "+c);
		cmd(tbtop, ".toolbar."+kbdfocus+".exit configure -background "+c);
	}
	if(id == "none")
	{
		kbdfocus = nil;
	}
	else
	{
		kbdfocus = id;
		c := cmd(tbtop, ". cget -selectcolor");
		cmd(tbtop, ".toolbar."+id+" configure -background "+c);
		cmd(tbtop, ".toolbar."+id+".icon configure -background "+c);
		cmd(tbtop, ".toolbar."+id+".text configure -background "+c);
		cmd(tbtop, ".toolbar."+id+".exit configure -background "+c);
	}
	cmd(tbtop, "update");
}

client_new(id: string)
{
	#sys->fprint(sys->fildes(2), "tabswin/toolbar: client_new(): %s\n", id);

	lw := "10w"; 
	if(env->getenv("AIMSGUI_MODE") == "light")
	{
		w := int tbtop.screenr.dx() / 4;
		w -= 16; # client icon
		w -= 16; # close icon
		w -= 8; # padding
		lw = string w;
	}

	f := ".toolbar."+id;
	cmd(tbtop, sys->sprint("frame %q -borderwidth 1 -relief ridge", f));
	cmd(tbtop, sys->sprint("label %q.icon -bitmap @/icons/aimsgui/window.bit", f));
	cmd(tbtop, sys->sprint("label %q.text -width %s -anchor nw -text { }", f, lw));
	cmd(tbtop, sys->sprint("button %q.exit -bitmap @/icons/tinytk/exit.bit" +
		" -relief flat -command {send close %q}", f, id));

	cmd(tbtop, sys->sprint("bind %q <Button-1> {send select %q}", f, id));
	cmd(tbtop, sys->sprint("bind %q.icon <Button-1> {send select %q}", f, id));
	cmd(tbtop, sys->sprint("bind %q.text <Button-1> {send select %q}", f, id));

	cmd(tbtop, sys->sprint("bind %q <Button-2> {send close %q}", f, id));
	cmd(tbtop, sys->sprint("bind %q.icon <Button-2> {send close %q}", f, id));
	cmd(tbtop, sys->sprint("bind %q.text <Button-2> {send close %q}", f, id));
	cmd(tbtop, sys->sprint("bind %q.exit <Button-2> {send close %q}", f, id));

	cmd(tbtop, sys->sprint("pack %q.icon -side left -padx 2", f));
	cmd(tbtop, sys->sprint("pack %q.text -side left", f));
	cmd(tbtop, sys->sprint("pack %q.exit -side left -padx 2", f));
	cmd(tbtop, sys->sprint("pack %q -side left -fill y", f));

	repack_startmenu();
	cmd(tbtop, "update");
}

client_name(id, label: string)
{
	#sys->fprint(sys->fildes(2), "tabswin/toolbar: client_name(): %s %s\n", id, label); 
	label = condenselabel(label);
	cmd(tbtop, ".toolbar." +id+".text configure -text '" + label);
	cmd(tbtop, "update");
}

client_del(id: string)
{
	e := tk->cmd(tbtop, "destroy .toolbar."+id);
	if(e == nil){
		if(tk->cmd(tbtop, ".toolbar."+id+" cget -relief") == "sunken")
			tkclient->wmctl(tbtop, sys->sprint("ctl %q untask", id));
		tkclient->wmctl(tbtop, sys->sprint("ctl %q kbdfocus 1", id));
		if(id == kbdfocus)
			kbdfocus = nil;
	}
	repack_startmenu();
	cmd(tbtop, "update");
}

layout(top: ref Tk->Toplevel)
{
	r := top.screenr;
	h := 22;
	cmd(top, ". configure -x " + string r.min.x +
			" -y " + string (r.max.y - h - 1) +
			" -width " + string r.dx() +
			" -height " + string h);
	cmd(top, "update");
	tkclient->onscreen(tbtop, "exact");
}

toolbar(ctxt: ref Draw->Context, startmenu: int,
		exec, select, close: chan of string): ref Tk->Toplevel
{
	(tbtop, nil) = tkclient->toplevel(ctxt, nil, nil, Tkclient->Plain);
	screenr = tbtop.screenr;

	cmd(tbtop, "button .b -text {XXX}");
	cmd(tbtop, "pack propagate . 0");

	tk->namechan(tbtop, exec, "exec");
	tk->namechan(tbtop, select, "select");
	tk->namechan(tbtop, close, "close");
	cmd(tbtop, "frame .toolbar");
	if (startmenu) {
		color := cmd(tbtop, ". cget -selectcolor");
		cmd(tbtop, "menubutton .toolbar.start -menu .m -relief raised" +
			" -borderwidth 1 -background " + color +  " -text {Add}");
		repack_startmenu();
	}
	cmd(tbtop, "pack .toolbar -fill both -expand 1");
	cmd(tbtop, "menu .m");
	return tbtop;
}

setup(shctxt: ref Context, finished: chan of int)
{
	ctxt := shctxt.copy(0);
	ctxt.run(shell->stringlist2list("run"::"/dis/aimsgui/tabswin/wmsetup"::nil), 0);
	# if no items in menu, then create some.
	if (tk->cmd(tbtop, ".m type 0")[0] == '!')
		ctxt.run(shell->stringlist2list(defaultscript::nil), 0);
	cmd(tbtop, "update");
	finished <-= 1;
}

condenselabel(label: string): string
{
	if(len label > 15){
		new := "";
		l := 0;
		while(len label > 15 && l < 3) {
			new += label[0:15]+"\n";
			label = label[15:];
			for(v := 0; v < len label; v++)
				if(label[v] != ' ')
					break;
			label = label[v:];
			l++;
		}
		label = new + label;
	}
	return label;
}

initbuiltin(ctxt: ref Context, nil: Sh): string
{
	if (tbtop == nil) {
		sys = load Sys Sys->PATH;
		sys->fprint(sys->fildes(2), "wm: cannot load wm as a builtin\n");
		raise "fail:usage";
	}
	ctxt.addbuiltin("menu", myselfbuiltin);
	ctxt.addbuiltin("delmenu", myselfbuiltin);
	ctxt.addbuiltin("error", myselfbuiltin);
	return nil;
}

whatis(nil: ref Sh->Context, nil: Sh, nil: string, nil: int): string
{
	return nil;
}

runbuiltin(c: ref Context, sh: Sh,
			cmd: list of ref Listnode, nil: int): string
{
	case (hd cmd).word {
	"menu" =>	return builtin_menu(c, sh, cmd);
	"delmenu" =>	return builtin_delmenu(c, sh, cmd);
	}
	return nil;
}

runsbuiltin(nil: ref Context, nil: Sh,
			nil: list of ref Listnode): list of ref Listnode
{
	return nil;
}

stderr(): ref Sys->FD
{
	return sys->fildes(2);
}

word(ln: ref Listnode): string
{
	if (ln.word != nil)
		return ln.word;
	if (ln.cmd != nil)
		return shell->cmd2string(ln.cmd);
	return nil;
}

menupath(title: string): string
{
	mpath := ".m."+title;
	for(j := 0; j < len mpath; j++)
		if(mpath[j] == ' ')
			mpath[j] = '_';
	return mpath;
}

repack_startmenu()
{
	cmd(tbtop, "pack .toolbar.start -side left -padx 4 -pady 4");
}

builtin_menu(nil: ref Context, nil: Sh, argv: list of ref Listnode): string
{
	n := len argv;
	if (n < 3 || n > 4) {
		sys->fprint(stderr(), "usage: menu topmenu [ secondmenu ] command\n");
		raise "fail:usage";
	}
	primary := (hd tl argv).word;
	argv = tl tl argv;

	if (n == 3) {
		w := word(hd argv);
		if (len w == 0)
			cmd(tbtop, ".m insert 0 separator");
		else
			cmd(tbtop, ".m insert 0 command -label " + tk->quote(primary) +
				" -command {send exec " + w + "}");
	} else {
		secondary := (hd argv).word;
		argv = tl argv;

		mpath := menupath(primary);
		e := tk->cmd(tbtop, mpath+" cget -width");
		if(e[0] == '!') {
			cmd(tbtop, "menu "+mpath);
			cmd(tbtop, ".m insert 0 cascade -label "+tk->quote(primary)+" -menu "+mpath);
		}
		w := word(hd argv);
		if (len w == 0)
			cmd(tbtop, mpath + " insert 0 separator");
		else
			cmd(tbtop, mpath+" insert 0 command -label "+tk->quote(secondary)+
				" -command {send exec "+w+"}");
	}
	return nil;
}

builtin_delmenu(nil: ref Context, nil: Sh, nil: list of ref Listnode): string
{
	delmenu(".m");
	cmd(tbtop, "menu .m");
	return nil;
}

delmenu(m: string)
{
	for (i := int cmd(tbtop, m + " index end"); i >= 0; i--)
		if (cmd(tbtop, m + " type " + string i) == "cascade")
			delmenu(cmd(tbtop, m + " entrycget " + string i + " -menu"));
	cmd(tbtop, "destroy " + m);
}

getself(): Shellbuiltin
{
	return myselfbuiltin;
}

cmd(top: ref Tk->Toplevel, c: string): string
{
	s := tk->cmd(top, c);
	if (s != nil && s[0] == '!')
		sys->fprint(stderr(), "tk error on %#q: %s\n", c, s);
	return s;
}

kill(pid: int, note: string): int
{
	fd := sys->open("/prog/"+string pid+"/ctl", Sys->OWRITE);
	if(fd == nil || sys->fprint(fd, "%s", note) < 0)
		return -1;
	return 0;
}

fatal(s: string)
{
	sys->fprint(sys->fildes(2), "wm: %s\n", s);
	kill(sys->pctl(0, nil), "killgrp");
	raise "fail:error";
}

bufferproc(in, out: chan of string)
{
	h, t: list of string;
	dummyout := chan of string;
	for(;;){
		outc := dummyout;
		s: string;
		if(h != nil || t != nil){
			outc = out;
			if(h == nil)
				for(; t != nil; t = tl t)
					h = hd t :: h;
			s = hd h;
		}
		alt{
		x := <-in =>
			t = x :: t;
		outc <-= s =>
			h = tl h;
		}
	}
}

con_cfg := array[] of
{
	"frame .cons",
	"scrollbar .cons.scroll -command {.cons.t yview}",
	"text .cons.t -width 60w -height 15w -bg white "+
		"-fg black -font /fonts/misc/latin1.6x13.font "+
		"-yscrollcommand {.cons.scroll set}",
	"pack .cons.scroll -side left -fill y",
	"pack .cons.t -fill both -expand 1",
	"pack .cons -expand 1 -fill both",
	"pack propagate . 0",
	"update"
};
nlines := 0;		# transcript length

consoleproc(ctxt: ref Draw->Context, sync: chan of string)
{
	iostdout := sys->file2chan("/chan", "wmstdout");
	if(iostdout == nil){
		sync <-= sys->sprint("cannot make /chan/wmstdout: %r");
		return;
	}
	iostderr := sys->file2chan("/chan", "wmstderr");
	if(iostderr == nil){
		sync <-= sys->sprint("cannot make /chan/wmstdout: %r");
		return;
	}

	sync <-= nil;

	(top, titlectl) := tkclient->toplevel(ctxt, "", "Errors", tkclient->Appl); 
	for(i := 0; i < len con_cfg; i++)
		cmd(top, con_cfg[i]);

	r := tk->rect(top, ".", Tk->Border|Tk->Required);
	cmd(top, ". configure -x " + string ((top.screenr.dx() - r.dx()) / 2 + top.screenr.min.x) +
				" -y " + string (r.dy() / 3 + top.screenr.min.y));

	tkclient->startinput(top, "ptr"::"kbd"::nil);
	tkclient->onscreen(top, "onscreen");
	tkclient->wmctl(top, "task");

	for(;;) alt {
	c := <-titlectl or
	c = <-top.wreq or
	c = <-top.ctxt.ctl =>
		if(c == "exit")
			c = "task";
		tkclient->wmctl(top, c);
	c := <-top.ctxt.kbd =>
		tk->keyboard(top, c);
	p := <-top.ctxt.ptr =>
		tk->pointer(top, *p);
	(off, nbytes, fid, rc) := <-iostdout.read =>
		if(rc == nil)
			break;
		alt{
		rc <-= (nil, "inappropriate use of file") =>;
		* =>;
		}
	(off, nbytes, fid, rc) := <-iostderr.read =>
		if(rc == nil)
			break;
		alt{
		rc <-= (nil, "inappropriate use of file") =>;
		* =>;
		}
	(off, data, fid, wc) := <-iostdout.write =>
		conout(top, data, wc);
	(off, data, fid, wc) := <-iostderr.write =>
		conout(top, data, wc);
		if(wc != nil)
			tkclient->wmctl(top, "untask");
	}
}

conout(top: ref Tk->Toplevel, data: array of byte, wc: Sys->Rwrite)
{
	if(wc == nil)
		return;

	s := string data;
	tk->cmd(top, ".cons.t insert end '"+ s);
	alt{
	wc <-= (len data, nil) =>;
	* =>;
	}

	for(i := 0; i < len s; i++)
		if(s[i] == '\n')
			nlines++;
	if(nlines > MAXCONSOLELINES){
		cmd(top, ".cons.t delete 1.0 " + string (nlines/4) + ".0; update");
		nlines -= nlines / 4;
	}

	tk->cmd(top, ".cons.t see end; update");
}
