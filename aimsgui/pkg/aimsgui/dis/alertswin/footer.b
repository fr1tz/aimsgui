implement Alertwinfooter;

include "sys.m";
	sys: Sys;
include "draw.m";
	draw: Draw;
	Screen, Display, Image, Rect, Point, Wmcontext, Pointer: import draw;
include "tk.m";
	tk: Tk;
include "tkclient.m";
	tkclient: Tkclient;
include "string.m";
	str: String;

Alertwinfooter: module 
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

drawcontext: ref Draw->Context;

stderr: ref sys->FD;
soundfd: ref sys->FD;

top: ref Tk->Toplevel;
ctop: chan of string;
caction: chan of string;

newalert()
{
	modpath := "/dis/aimsgui/alertswin/alertwin2.dis";
	#sys->fprint(stderr, "alertwin/footer: spawning %s\n", modpath);
	mod := load Alertwinfooter modpath;
	if(mod == nil) 
		badmodule(modpath);
	else
		mod->init(drawcontext, "alert"::nil);
}

action(s: string)
{
	fields := str->unquoted(s);
	if(hd fields == "button_clicked")
	{
		spawn newalert();
	}
	T("update");
}

badmodule(p: string)
{
	sys->fprint(stderr, "alertwin/footer: cannot load %s: %r\n", p);
	raise "fail:bad module";
}

init(ctxt: ref Draw->Context, argv: list of string)
{
	drawcontext = ctxt;
	if(sys == nil) sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);
	sys->pctl(sys->NEWPGRP, nil);

	if(draw == nil) draw = load Draw Draw->PATH;
	if(draw == nil) badmodule(Draw->PATH);
	if(tk == nil) tk = load Tk Tk->PATH; 
	if(tk == nil) badmodule(Tk->PATH);
	if(str == nil) str = load String String->PATH; 
	if(str == nil) badmodule(String->PATH);
	if(tkclient == nil) tkclient = load Tkclient Tkclient->PATH;
	if(tkclient == nil) badmodule(Tkclient->PATH);

	if(ctxt == nil) {
		sys->fprint(stderr, "alertwin/footer: must run under a window manager\n");
		raise "fail:no wm";
	}

	tkclient->init();
	(top,ctop) = tkclient->toplevel(ctxt, nil, "Alert", Tkclient->Plain);

	caction = chan of string;
	tk->namechan(top, caction, "action");

	T("frame .f");
	T("pack .f -side top -fill both -padx 4 -pady 4");
	T("frame .f.bframe");
	T("pack .f.bframe -side left");
	T("radiobutton .f.bframe.but -text {Add Alert} -variable pc" +
	  " -value 0 -indicatoron 0 -borderwidth 1 -command { send action button_clicked }");
	T("pack .f.bframe.but -side left");


	tkclient->startinput(top, "ptr"::nil);
	tkclient->wmctl(top, "wintype footer"); 
	tkclient->onscreen(top, nil);

	for(;;) alt{
	c := <-top.ctxt.kbd =>
		tk->keyboard(top, c);
	m := <-top.ctxt.ptr =>
		tk->pointer(top, *m);
	s := <-ctop or
	s  = <-top.ctxt.ctl or
	s  = <-top.wreq =>
		tkclient->wmctl(top, s);
	s := <-caction =>
		action(s);
	}
}

T(c: string): string
{
	s := tk->cmd(top, c);
	if (s != nil && s[0] == '!')
		sys->fprint(stderr, "alertwin/footer: tk error on %#q: %s\n", c, s);
	return s;
}
