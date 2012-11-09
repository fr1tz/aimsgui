Malert: module 
{
	PATH: con "/dis/aimsgui/alert.dis";

	init: fn(nil: ref Draw->Context, argv: list of string);
	run:  fn(sc: chan of string);
	ctl:  fn(cmdline: string): string;
	ctln: fn(cmdline: string);
};
