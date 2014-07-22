%MOIN*%
%FSTAX12Y12*%
%IPPOS*%
%LPD*%
%ADD10C,0.02*%
D10*
G04 a flash*
X02Y02D03*
G04 a line*
X04Y02D02*
X04Y04D01*

G04 ------------------------------------------------------------------------------*

G04 single quadrant*
G74*

G04 clockwise*
G01X06Y02D02*
G02X06Y04I01J01D01*

G04 direct*
G01X08Y02D02*
G03X08Y04I01J01D01*

G04 varying radius*
G01X10Y02D02*
G02X10Y04I005J015D01*

G04 multi quadrant*
G75*

G04 clockwise short*
G01X12Y02D02*
G02X12Y04I01J01D01*

G04 clockwise long*
G01X16Y02D02*
G02X16Y04I-01J01D01*

G04 direct long*
G01X18Y02D02*
G03X18Y04I01J01D01*

G04 direct short*
G01X22Y02D02*
G03X22Y04I-01J01D01*

G04 varying radius*
G01X26Y02D02*
G02X26Y04I005J015D01*

G04 ------------------------------------------------------------------------------*

G04 overlapping start/end*

G74*
G01X02Y06D02*
G02X02Y06I01J01D01*

G75*
G01X04Y06D02*
G02X04Y06I01J01D01*

G74*
G01X08Y06D02*
G03X08Y06I01J01D01*

G75*
G01X10Y06D02*
G03X10Y06I01J01D01*

G04 ------------------------------------------------------------------------------*

G04 split circle*

G74*

G01X14Y06D02*
G02X14Y08I01J01D01*
G01X14Y08D02*
G02X16Y08I01J01D01*
G01X16Y08D02*
G02X16Y06I01J01D01*
G01X16Y06D02*
G02X14Y06I01J01D01*

G04 ------------------------------------------------------------------------------*

M02*
