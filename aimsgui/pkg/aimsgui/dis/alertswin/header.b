implement Alertwinheader;

include "sys.m";
	sys: Sys;
include "draw.m";
	draw: Draw;
	Screen, Display, Image, Rect, Point, Wmcontext, Pointer: import draw;
include "tk.m";
	tk: Tk;
include "tkclient.m";
	tkclient: Tkclient;


Alertwinheader: module 
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

stderr: ref sys->FD;
soundfd: ref sys->FD;

top: ref Tk->Toplevel;
ctop: chan of string;

badmodule(p: string)
{
	sys->fprint(stderr, "alertgui: cannot load %s: %r\n", p);
	raise "fail:bad module";
}

init(ctxt: ref Draw->Context, argv: list of string)
{
	if(sys == nil) sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);

	if(draw == nil) draw = load Draw Draw->PATH;
	if(draw == nil) badmodule(Draw->PATH);
	if(tk == nil) tk = load Tk Tk->PATH; 
	if(tk == nil) badmodule(Tk->PATH);
	if(tkclient == nil) tkclient = load Tkclient Tkclient->PATH;
	if(tkclient == nil) badmodule(Tkclient->PATH);

	if(ctxt == nil) {
		sys->fprint(stderr, "alertwin/header: must run under a window manager\n");
		raise "fail:no wm";
	}

	tkclient->init();
	(top,ctop) = tkclient->toplevel(ctxt, nil, nil, Tkclient->Plain);

	T("frame .f");
	T("pack .f -side top -fill both -padx 1 -pady 4");
	T("frame .f.gframe");
	T("pack .f.gframe -side left");
		T("label .f.gframe.label -width 105 -text {Game} -anchor nw");
		T("pack .f.gframe.label -side left -fill x");
	T("frame .f.lframe");
	T("pack .f.lframe -side left");
		T("label .f.lframe.label -width 85 -text {Location} -anchor nw");
		T("pack .f.lframe.label -side left -fill x");
	T("frame .f.pcframe");
	T("pack .f.pcframe -side left");
		T("label .f.pcframe.label -width 235 -text {Minimum number of players}");
		T("pack .f.pcframe.label -side left -fill x");
	T("frame .f.pnframe");
	T("pack .f.pnframe -side left");
		T("label .f.pnframe.label -width 80 -text {Player name}");
		T("pack .f.pnframe.label -side left -fill x");


	#tkclient->startinput(top, "ptr"::"kbd"::nil);
	tkclient->wmctl(top, "wintype header");
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
	}
}

T(c: string): string
{
	s := tk->cmd(top, c);
	if (s != nil && s[0] == '!')
		sys->fprint(stderr, "alertwin/header: tk error on %#q: %s\n", c, s);
	return s;
}

