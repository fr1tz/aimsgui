Msoundplayer: module 
{
	init:  fn(nil: ref Draw->Context, argv: list of string);
	setup: fn(argv: list of string, errors: ref sys->FD);
	play:  fn(sound: string);
};
