Aimsgametype: module 
{
	PATH: con "/dis/aimsgui/gametype.dis";

	init:  fn(nil: ref Draw->Context, argv: list of string);
	setup: fn(stderr: ref sys->FD);
	match: fn(gamecode, candidate: string): int;
};
