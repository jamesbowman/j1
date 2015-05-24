header 1+       : 1+        d# 1 + ;
header 1-       : 1-        d# -1 + ;
header 0=       : 0=        d# 0 = ;
header cell+    : cell+     d# 2 + ;

header <>       : <>        = invert ; 
header >        : >         swap < ; 
header 0<       : 0<        d# 0 < ; 
header 0>       : 0>        d# 0 > ;
header 0<>      : 0<>       d# 0 <> ;
header u>       : u>        swap u< ; 

: eol   ( u -- u' false | true )
    d# -1 +
    dup 0= dup if
                        ( 0 true -- )
        nip
    then
;

header ms
: ms
    begin
        d# 15000 begin
        eol until
    eol until
;


header key?
: key?
    d# 0 io@
    d# 4 and
    0<>
;

header key
: key
    begin
        key?
    until
    d# 0 io@ d# 8 rshift
    d# 0 d# 2 io!
;

: ready
    d# 0 io@
    d# 2 and
    0=
;

header emit
: emit
    begin ready until
    h# 0 io!
;

header cr
: cr
    d# 13 emit
    d# 10 emit
;

header space
: space
    d# 32 emit
;

header bl
: bl
    d# 32
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

header .
: . hex4 space ;

header true     : true   d# -1 ; 
header rot      : rot   >r swap r> swap ; 
header -rot     : -rot  swap >r swap r> ; 
header tuck     : tuck  swap over ; 
header 2drop    : 2drop drop drop ; 
header ?dup     : ?dup  dup if dup then ;

header 2dup     : 2dup  over over ; 
header +!       : +!    tuck @ + swap ! ; 
header 2swap    : 2swap rot >r rot r> ;

header c@
: c@
    dup @ swap
    d# 1 and d# 3 lshift rshift
    d# 255 and
;

header c!
: c! ( u c-addr -- )
    dup>r d# 1 and if
        d# 8 lshift
        r@ @ h# 00ff and
    else
        h# 00ff and
        r@ @ h# ff00 and
    then
    or r> !
;

header count
: count
    dup 1+ swap c@
;


: bounds ( a n -- a+n a )
    over + swap
;

header type
: type
    bounds
    begin
        2dupxor
    while
        dup c@ emit
        1+
    repeat
    2drop
;

create base $a ,
create ll 0 ,
create dp 0 ,
create tib 80 allot

\ header words : words
\     ll @
\     begin
\         dup
\     while
\         cr
\         dup .
\         dup cell+
\         count type
\         space
\         @
\     repeat
\     drop
\ ;
\ 
\ header dump : dump ( addr u -- )
\     cr over hex4
\     begin  ( addr u )
\         ?dup
\     while
\         over c@ space hex2
\         1- swap 1+   ( u' addr' )
\         dup h# f and 0= if  ( next line? )
\             cr dup hex4
\         then
\         swap
\     repeat
\     drop
\ ;

header negate   : negate    invert 1+ ; 
header -        : -         negate + ; 
header abs      : abs       dup 0< if negate then ; 
header 2*       : 2*        d# 1 lshift ; 
header 2/       : 2/        d# 1 rshift ; 
header here     : here      dp @ ;
header depth    : depth     depths h# f and ;

: /string
    dup >r - swap r> + swap
; 

header aligned
: aligned
    1+ h# -2 and
; 

: d+                              ( augend . addend . -- sum . ) 
    rot + >r                      ( augend addend) 
    over +                        ( augend sum) 
    dup rot                       ( sum sum augend) 
    u< if                         ( sum) 
        r> 1+ 
    else 
        r> 
    then                          ( sum . ) 
; 
: s>d dup 0< ;
: m+
    s>d d+
;

create scratch 0 ,

header um*
: um*  ( u1 u2 -- ud ) 
    scratch ! 
    d# 0. 
    d# 16 begin
        >r
        2dup d+ 
        rot dup 0< if 
            2* -rot 
            scratch @ d# 0 d+ 
        else 
            2* -rot 
        then 
        r> eol
    until
    rot drop 
; 

header accept
: accept
    drop dup
    begin
        key
        dup h# 0a = if drop swap - exit then
        dup h# 20 < if drop bl then
        dup emit
        over c! 1+
    again
;

: snap
    cr depth hex2 space
    begin
        depth
    while
        .
    repeat
    cr
    [char] # emit
    begin again
;

: digit? ( c -- u f )
   dup h# 39 > h# 100 and +
   dup h# 140 > h# 107 and - h# 30 -
   dup base @ u<
;

: ud*      ( ud1 d2 -- ud3 ) \ 32*16->32 multiply
    dup >r um* drop
    swap r> um* rot +
;

: >number ( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )
    begin
        dup
    while
        over c@ digit?
        0= if drop exit then
        >r 2swap base @ ud*
        r> m+ 2swap
        d# 1 /string
    repeat
;

header fill
: fill ( c-addr u char -- ) ( 6.1.1540 ) 
  >r  bounds 
  begin
    2dupxor 
  while
    r@ over c! 1+ 
  repeat
  r> drop 2drop
; 

header erase
: erase
    d# 0 fill
;

header !        :noname     !        ;
header +        :noname     +        ;
header xor      :noname     xor      ;
header and      :noname     and      ;
header or       :noname     or       ;
header invert   :noname     invert   ;
header =        :noname     =        ;
header <        :noname     <        ;
header u<       :noname     u<       ;
header swap     :noname     swap     ;
header dup      :noname     dup      ;
header drop     :noname     drop     ;
header over     :noname     over     ;
header nip      :noname     nip      ;
header @        :noname     @        ;
header io!      :noname     io!      ;
header rshift   :noname     rshift   ;
header lshift   :noname     lshift   ;
\ 
\ \ >r
\ \ r>
\ \ r@
\ \ exit
\ 

: main
    d# 60 begin
        d# 1 ms
        [char] - emit
    eol until

    \ words

    cr cr cr
    h# 1947 begin
        cr dup hex8
        2*
        dup 0=
    until
    cr

    cr d# 0 @ hex8
    cr d# 4 @ hex8
    cr h# 3fc0 @ hex8
    h# 947 h# 3fc0 !
    cr h# 3fc0 @ hex8
    cr

    begin
        d# 0 io@ cr hex8
        d# 100 ms
    again
    begin again

    begin key? while key drop repeat

    begin
        cr
        tib d# 30 accept >r
        d# 0. tib r> >number
        2drop hex4 space hex4
    again

    snap
;

meta
    $3f80 org 
target

: b.key
    begin
        d# 0 io@
        d# 4 and
    until
    d# 0 io@ d# 8 rshift
    d# 0 d# 2 io!
;

: b.32
    b.key
    b.key d# 8 lshift or
    b.key d# 16 lshift or
    b.key d# 24 lshift or
;

meta
    $3fc0 org 
target

: bootloader
    b.32 d# 0
    begin
        2dupxor
    while
        b.32 over !
        d# 4 +
    repeat
    d# 2 >r
;

meta
    link @ t,
    link @ t' ll t!
    there  t' dp t!
target
