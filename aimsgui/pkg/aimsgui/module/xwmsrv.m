# Copyright © 1995-1999 Lucent Technologies Inc.
# Portions Copyright © 1997-2000 Vita Nuova Limited
# Portions Copyright © 2000-2010 Vita Nuova Holdings Limited
# Portions Copyright © 2012 Michael Goldener <mg@wasted.ch>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License 
# (`GPL') as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

Xwmsrv: module
{
	PATH: con "/dis/aimsgui/lib/xwmsrv.dis";

	init:   fn(): 	(chan of (string, chan of (string, ref Draw->Wmcontext)),
		chan of (ref Client, chan of string),
		chan of (ref Client, array of byte, Sys->Rwrite));

	find:   fn(p: Draw->Point): ref Client;
	top:    fn(): ref Client;

	Window: adt {
		tag:   string;
		r:     Draw->Rect;
		img:   ref Draw->Image;
	};

	Client: adt {
		kbd:        chan of int;
		ptr:        chan of ref Draw->Pointer;
		ctl:        chan of string;
		stop:       chan of int;
		flags:      int;                   # general purpose
		attrs:      array of string;       # general purpose
		cursor:	    string;                # hack
		wins:	    list of ref Window;
		znext:	    cyclic ref Client;

		# private:
		images:	    chan of (ref Draw->Point, ref Draw->Image, chan of int);
		id:         int;                   # index into clients array
		fid:        int;
		token:      int;
		wmctxt:     ref Draw->Wmcontext;

		window:     fn(c: self ref Client, tag: string): ref Window;
		contains:   fn(c: self ref Client, p: Draw->Point): int;
		image:	    fn(c: self ref Client, tag: string):	ref Draw->Image;
		setimage:   fn(c: self ref Client, tag: string,  i: ref Draw->Image): int;  # only in response to some msgs.
		setorigin:  fn(c: self ref Client, tag: string, o: Draw->Point): int;       # only in response to some msgs.
		top:		fn(c: self ref Client);   # bring to top
		bottom:     fn(c: self ref Client);   # send to bottom
		hide:       fn(w: self ref Client);   # move offscreen
		unhide:     fn(w: self ref Client);   # move onscreen
		remove:     fn(w: self ref Client);
	};
};

