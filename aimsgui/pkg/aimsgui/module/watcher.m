Mwatcher: module 
{
	init: fn(nil: ref Draw->Context, argv: list of string);
	run: fn(argv: list of string, sc: chan of (int, string));
};
