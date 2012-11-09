implement Mwatcher;

WATCHERTYPE: con "rotc-eth";

include "rotc.B";

check_server(fields: list of string): int
{
	gametype := hd tl tl fields;
	(re,nil) := regex->compile("\\[", 0);
	a  := regex->execute(re, gametype);
	if(a == nil)
		return 1;
	return 0;
}
