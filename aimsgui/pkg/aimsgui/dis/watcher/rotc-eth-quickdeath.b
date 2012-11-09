implement Mwatcher;

WATCHERTYPE: con "rotc-eth-quickdeath";

include "rotc.B";

check_server(fields: list of string): int
{
	gametype := hd tl tl fields;
	(re,nil) := regex->compile("QUICKDEATH", 0);
	a  := regex->execute(re, gametype);
	if(a == nil)
		return 0;
	return 1;
}
