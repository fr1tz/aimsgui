Msrvloc: module 
{
	PATH: con "/dis/aimsgui/srvloc.dis";

	init:  fn(nil: ref Draw->Context, argv: list of string);
	setup: fn(stderr: ref sys->FD);
	check: fn(locationcode, candidate: string): int;
};
