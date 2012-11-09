implement Alertwin2;

include "sys.m";
	sys: Sys;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "draw.m";
	draw: Draw;
	Screen, Display, Image, Rect, Point, Wmcontext, Pointer: import draw;
include "tk.m";
	tk: Tk;
include "tkclient.m";
	tkclient: Tkclient;
include "string.m";
	str: String;
include "../../module/alert.m";
	alert: Malert;

Alertwin2: module 
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

stderr: ref sys->FD;
soundfd: ref sys->FD;

top: ref Tk->Toplevel;
ctop: chan of string;
caction: chan of string;
bgcolor: string;
gametype: string;
location: string;
playercount: int;
flashing: int;
muted: int;

action(s: string)
{
	#sys->fprint(stderr, "alertwin2: got action: %s\n", s);
	fields := str->unquoted(s);

	if(hd fields == "exit")
	{
		#tkclient->wmctl(top, "exit");
		alert->ctln("exit");
		exit;
	}
	else if(hd fields == "update_alert")
	{
		update_alert();
	}
	else if(hd fields == "off")
	{
		flashing = 1; toggle_flash();
		tkclient->settitle(top, "Alert [off]");
		#T(".f.bframe.disablebut select");
	}
	else if(hd fields == "running")
	{
		flashing = 1; toggle_flash();
		tkclient->settitle(top, "Alert [on]");
		args := tl fields;
		gt := hd args; args = tl args;
		loc := hd args; args = tl args;
		pc := int hd args;
		if(gametype != gt)
		{
			gametype = gt;
			#desc := "Unknown";
			#buf := bufio->open("/mnt/aims/alert/games", bufio->OREAD);
			#if(buf == nil) 
			#	sys->fprint(stderr, "alertgui: can't open /mnt/aims/alert/games: %r\n");
			#else
			#{
			#	while((s := buf.gets('\n')) != nil)
			#	{
			#		fields := str->unquoted(s);
			#		if(hd fields == gametype)
			#		{
			#			desc = str->quoted(tl fields);
			#			break;
			#		}
			#	}
			#	buf.close();
			#}
			T(".f.gframe.but configure -bitmap "+tk->quote("@/icons/game/"+gametype+".bit"));
			T(".f.tframe.label configure -text "+tk->quote(gametype));
		}
		if(location != loc)
		{
			location = loc;
			#desc := "Unknown";
			#buf := bufio->open("/mnt/aims/alert/locations", bufio->OREAD);
			#if(buf == nil) 
			#	sys->fprint(stderr, "alertgui: can't open /mnt/aims/alert/locations: %r\n");
			#else
			#{
			#	while((s := buf.gets('\n')) != nil)
			#	{
			#		fields := str->unquoted(s);
			#		if(hd fields == location)
			#		{
			#			desc = str->quoted(tl fields);
			#			break;
			#		}
			#	}
			#	buf.close();
			#}
			T(".f.lframe.but configure -bitmap "+tk->quote("@/icons/srvloc/"+location+".bit"));
		}
		if(playercount != pc)
		{
			playercount = pc;
			if(playercount == 0)
				T(".f.pcframe.but configure -text {OFF}");
			else
				T(".f.pcframe.but configure -text "+tk->quote(string playercount));
		}
	}
	else if(hd fields == "ringing")
	{
		tkclient->settitle(top, "Alert [ringing]");
		tkclient->wmctl(top, "untask");
	}
	else if(hd fields == "ring!")
	{
		toggle_flash();
		if(!muted && soundfd != nil && sys->fprint(soundfd, "alert.%s", gametype) < 0)
		{
			sys->fprint(stderr, "alertgui: error writing to /chan/sound: %r\n");	
			soundfd = nil;
		}		 
	}
	else if(hd fields == "toggleflash")
	{
		toggle_flash();
	}
	else if(hd fields == "togglemute")
	{
		muted = !muted;
		if(muted)
			T(".f.oframe.mutebut configure -image image_speaker_muted");
		else
			T(".f.oframe.mutebut configure -image image_speaker_fullvol");
	}
	else if(hd fields == "change_game")
	{
		args := tl fields;
		gametype = hd args;
		desc := str->quoted(tl args);
		#T(".f.gframe.but configure -text "+tk->quote(desc));
		T(".f.gframe.but configure -bitmap "+tk->quote("@/icons/game/"+gametype+".bit"));
		T(".f.tframe.label configure -text "+tk->quote(gametype));
		update_alert();
	}
	else if(hd fields == "change_location")
	{
		args := tl fields;
		location = hd args;
		desc := str->quoted(tl args);
		#T(".f.lframe.but configure -text "+tk->quote(desc));
		T(".f.lframe.but configure -bitmap "+tk->quote("@/icons/srvloc/"+location+".bit"));
		update_alert();
	}
	else if(hd fields == "change_playercount")
	{
		args := tl fields;
		playercount = int hd args;
		if(playercount == 0)
			T(".f.pcframe.but configure -text {OFF}");
		else
			T(".f.pcframe.but configure -text "+tk->quote(string playercount));
		update_alert();
	}
	else if(hd fields == "changing_name")
	{
		T(".f.pnframe.entry configure -background red");
	}
	else if(hd fields == "change_name")
	{
		args := tl fields;
		k: string;
		if(len args == 0) 
			k = "done";
		else
			k = hd args;
		if(k == "done")
		{
			alert->ctl("pname " + T(".f.pnframe.entry get"));
		}
		else
		{
			T(".f.pnframe.entry delete sel.first sel.last");
			T(".f.pnframe.entry insert insert " + k);
		}
	}
	else if(hd fields == "pname")
	{
		T(".f.pnframe.entry configure -background " + bgcolor);
		T(".f.pnframe.entry delete 0 end");
		T(".f.pnframe.entry insert end " + tk->quote(str->quoted(tl fields)));
		T(".f.pnframe.entry icursor end");
		T("focus .");
	}
	T("update");
}

badmodule(p: string)
{
	sys->fprint(stderr, "alertgui: cannot load %s: %r\n", p);
	raise "fail:bad module";
}

init(ctxt: ref Draw->Context, argv: list of string)
{
	if(sys == nil) sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);
	sys->pctl(sys->NEWPGRP, nil);

	if(bufio == nil) bufio = load Bufio Bufio->PATH;
	if(bufio == nil) badmodule(Bufio->PATH);
	if(draw == nil) draw = load Draw Draw->PATH;
	if(draw == nil) badmodule(Draw->PATH);
	if(tk == nil) tk = load Tk Tk->PATH; 
	if(tk == nil) badmodule(Tk->PATH);
	if(str == nil) str = load String String->PATH; 
	if(str == nil) badmodule(String->PATH);
	if(tkclient == nil) tkclient = load Tkclient Tkclient->PATH;
	if(tkclient == nil) badmodule(Tkclient->PATH);
	if(alert == nil) alert = load Malert Malert->PATH;
	if(alert == nil) badmodule(Malert->PATH);

	if(ctxt == nil) {
		sys->fprint(stderr, "alertgui: must run under a window manager\n");
		raise "fail:no wm";
	}

	gamesbuf := bufio->open("/mnt/aims/alertlist/v1/games", bufio->OREAD);
	if(gamesbuf == nil) {
		sys->fprint(stderr, "alertgui: can't open /mnt/aims/alertlist/v1/games: %r\n");
		raise "fail:error";		
	}

	locationsbuf := bufio->open("/mnt/aims/alertlist/v1/locations", bufio->OREAD);
	if(locationsbuf == nil) {
		sys->fprint(stderr, "alertgui: can't open /mnt/aims/alertlist/v1/locations: %r\n");
		raise "fail:error";		
	}

	soundfd = sys->open("/chan/sound", sys->OWRITE);
	if(soundfd == nil)
		sys->fprint(stderr, "alertgui: can't open /chan/sound: %r\n");

	tkclient->init();
	(top,ctop) = tkclient->toplevel(ctxt, nil, "Alert", Tkclient->Plain);

	bgcolor = T(". cget -background");
	playercount = 0;

	caction = chan of string;
	tk->namechan(top, caction, "action");

	T("image create bitmap image_speaker_fullvol " +
	  " -file @/icons/aimsgui/speaker.fullvol.bit" +
	  " -maskfile @/icons/aimsgui/speaker.fullvol.mask.bit"); 
	T("image create bitmap image_speaker_muted " +
	  " -file @/icons/aimsgui/speaker.muted.bit" +
	  " -maskfile @/icons/aimsgui/speaker.muted.mask.bit"); 
	T("menu .f.gamesmenu");
	while((s := gamesbuf.gets('\n')) != nil)
	{
		fields := str->unquoted(s);
		if(gametype == nil)
			gametype = hd fields;
		label := str->quoted(tl fields);
		cmd := "send action change_game " + s;
		T(".f.gamesmenu add command -label "+tk->quote(label)+
		  " -command "+tk->quote(cmd));
	}
	gamesbuf.close(); gamesbuf = nil;
	T("menu .f.locationmenu");
	while((s = locationsbuf.gets('\n')) != nil)
	{
		fields := str->unquoted(s);
		if(location == nil)
			location = hd fields;
		label := str->quoted(tl fields);
		cmd := "send action change_location " + s;
		T(".f.locationmenu add command -label "+tk->quote(label)+
		  " -command "+tk->quote(cmd));
	}
	locationsbuf.close(); locationsbuf = nil;
	T("menu .f.pcmenu");
		T(".f.pcmenu add command -label OFF -command {send action change_playercount 0}");
		for(c := 1; c <= 24; c++) {
			label := string c + " player";
			if(c > 1)
				label = label + "s";
			cmd := "send action change_playercount " + string c;
			T(".f.pcmenu add command -label "+tk->quote(label)+
			  " -command "+tk->quote(cmd));
		}
	T("menu .f.optmenu");
		T(".f.optmenu add command -label Remove -command {send action exit}");
	T("frame .f");
	T("pack .f -side top -fill both -padx 2 -pady 2");
	T("frame .f.gframe");
	T("pack .f.gframe -side left -fill x");
		T("menubutton .f.gframe.but -relief raised" +
		  " -borderwidth 1 -anchor nw -menu .f.gamesmenu" +
		  " -bitmap @/icons/game/alux.bit");
		T("pack .f.gframe.but -side left -fill x -padx 1");
	T("frame .f.lframe");
	T("pack .f.lframe -side left -fill x");
		T("menubutton .f.lframe.but -relief raised" +
		  " -borderwidth 1 -anchor nw -menu .f.locationmenu" +
		  " -bitmap @/icons/srvloc/-a.bit");
		T("pack .f.lframe.but -side left -fill x -padx 1");
	T("frame .f.pcframe");
	T("pack .f.pcframe -side left -fill y");
		T("menubutton .f.pcframe.but -width 25 -relief raised" +
		  " -borderwidth 1 -anchor center -menu .f.pcmenu" +
		  " -text {"+T(".f.pcmenu entrycget 0 -text")+"}");
		T("pack .f.pcframe.but -side left -fill both -padx 1");
	T("frame .f.tframe");
	T("pack .f.tframe -side left -fill x -expand 1");
		T("label .f.tframe.label -width 25 -anchor nw -text alux");
		T("pack .f.tframe.label -side left -fill x -expand 1 -padx 1");
	T("frame .f.pnframe");
	#T("pack .f.pnframe -side left");
		T("entry .f.pnframe.entry -width 75");
		T("pack .f.pnframe.entry -side left -padx 4");
		T("bind .f.pnframe.entry <FocusIn> { send action changing_name }");
		T("bind .f.pnframe.entry <FocusOut> { send action change_name done }");
		T("bind .f.pnframe.entry <KeyPress> { send action change_name %A }");
		T(".f.pnframe.entry insert end JohnDoe");
	T("frame .f.oframe");
	T("pack .f.oframe -side left");
		T("button .f.oframe.mutebut -image image_speaker_fullvol" +
			" -borderwidth 0 -takefocus 0 -command { send action togglemute }");
		T("pack .f.oframe.mutebut -side left -padx 1");
		T("menubutton .f.oframe.but -width 15 -relief raised" +
		  " -borderwidth 1 -anchor nw -menu .f.optmenu" +
		  " -text {...}");
		T("pack .f.oframe.but -side left -padx 1");
	#T("frame .f.eframe");
	#T("pack .f.eframe -side left -expand 1 -fill x");
	#	T("button .f.eframe.button -bitmap @/icons/tinytk/exit.bit -command {send action exit}");
	#	T("pack .f.eframe.button -side right");


	tkclient->startinput(top, "ptr"::"kbd"::nil);
	tkclient->onscreen(top, nil);

	spawn alert->run(caction);
	<-caction; # ctl message

	alert->ctln("off");

	for(;;) alt{
	c := <-top.ctxt.kbd =>
		tk->keyboard(top, c);
	m := <-top.ctxt.ptr =>
		tk->pointer(top, *m);
	s := <-ctop or
	s  = <-top.ctxt.ctl or
	s  = <-top.wreq =>
		if(s == "exit")
			alert->ctl("exit");
		tkclient->wmctl(top, s);
	s := <-caction =>
		action(s);
	}
}

T(c: string): string
{
	s := tk->cmd(top, c);
	if (s != nil && s[0] == '!')
		sys->fprint(stderr, "alertgui: tk error on %#q: %s\n", c, s);
	return s;
}

toggle_flash()
{
	if(flashing == 1)
		T(". configure -background "+bgcolor);
	else
		T(". configure -background red");
	flashing = !flashing;
}

update_alert()
{
	#sys->fprint(stderr, "alertwin2: update alert(): ");
	flashing = 1; toggle_flash();
	if(playercount == 0)
	{
		#sys->fprint(stderr, "off\n");
		alert->ctl("off");
	}
	else
	{
		s := sys->sprint("on %s %s %s", gametype, location, string playercount);
		#sys->fprint(stderr, "%s\n", s);
		alert->ctl(s);
	}
}
