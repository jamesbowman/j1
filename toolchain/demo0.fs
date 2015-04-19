: 1+        d# 1 + ;
: 0=        d# 0 = ;
: 0<>       0= invert ;

: key?
    d# 0 io@
    d# 4 and
    0<>
;

: key
    begin
        key?
    until
    d# 0 io@ d# 8 rshift
    d# 0 d# 1 io!
;

: emit
    begin
        d# 0 io@
        d# 2 and
        0=
    until
    h# 0 io!
;

: cr
    d# 13 emit
    d# 10 emit
;

: space
    d# 32 emit
;

: hex1
    h# f and
    dup d# 10 < if
        [char] 0
    else
        d# 55
    then
    +
    emit
;

: hex2
    dup d# 4 rshift hex1 hex1
;

: hex4
    dup d# 8 rshift hex2 hex2
;

: hex8
    dup d# 16 rshift hex4 hex4
;

: . hex4 ;

: eol   ( u -- u' false | true )
    d# -1 +
    dup 0= dup if
                        ( 0 true -- )
        nip
    then
;

: ms
    begin
        d# 15000 begin
        eol until
    eol until
;

: main
    d# 60 begin
        d# 1 ms
        [char] - emit
    eol until

    cr cr cr cr
    d# 64 emit h# abcd hex4

    h# 55aa h# c5 !

    d# 0 begin
        cr
        dup hex4
        space
        dup @ hex4
        1+
        dup d# 200 =
    until
    cr cr

    begin
        key?
    while
        key drop
    repeat

    d# 0
    begin
        cr dup hex4
        space d# 0 io@ hex4
        d# 1000 ms
        key? if
            cr key hex4
        then
        1+
    again

    begin
        key hex4 cr
    again
    [char] # emit
;
