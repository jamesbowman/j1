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
: . hex8 space ;

header false    : false d# 0 ; 
header true     : true  d# -1 ; 
header rot      : rot   >r swap r> swap ; 
header -rot     : -rot  swap >r swap r> ; 
header tuck     : tuck  swap over ; 
header 2drop    : 2drop drop drop ; 
header ?dup     : ?dup  dup if dup then ;

header 2dup     : 2dup  over over ; 
header +!       : +!    tuck @ + swap ! ; 
header 2swap    : 2swap rot >r rot r> ;

header min      : min   2dup< if drop else nip then ;
header max      : max   2dup< if nip else drop then ;

header c@
: c@
    dup @ swap
    d# 3 and d# 3 lshift rshift
    d# 255 and
;

: hi16
    d# 16 rshift d# 16 lshift
;

: lo16
    d# 16 lshift d# 16 rshift
;

header uw@
: uw@
    dup @ swap
    d# 2 and d# 3 lshift rshift
    lo16
;

header w!
: w! ( u c-addr -- )
    dup>r d# 2 and if
        d# 16 lshift
        r@ @ lo16
    else
        lo16
        r@ @ hi16
    then
    or r> !
;

header c!
: c! ( u c-addr -- )
    dup>r d# 1 and if
        d# 8 lshift
        h# 00ff
    else
        h# 00ff and
        h# ff00
    then
    r@ uw@ and
    or r> w!
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

create base     $a ,
create ll       0 ,
create dp       0 ,
create tib#     0 ,
create >in      0 ,
create tib 80 allot

header words : words
    ll uw@
    begin
        dup
    while
        cr
        dup .
        dup cell+
        count type
        space
        uw@
    repeat
    drop
;

header dump : dump ( addr u -- )
    cr over hex4
    begin  ( addr u )
        ?dup
    while
        over c@ space hex2
        1- swap 1+   ( u' addr' )
        dup h# f and 0= if  ( next line? )
            cr dup hex4
        then
        swap
    repeat
    drop cr
;

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
    d# 3 + d# -4 and
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

: d1+ d# 1. d+ ; 

: dnegate 
    invert swap invert swap 
    d1+ 
; 

: dabs ( d -- ud )
    dup 0< if dnegate then
; 

: s>d dup 0< ;
: m+
    s>d d+
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

create scratch 0 ,

header um*
: um*  ( u1 u2 -- ud ) 
    scratch ! 
    d# 0. 
    d# 32 begin
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
: *
    um* drop
;

header accept
: accept
    d# 30 emit
    drop dup
    begin
        key
        dup h# 0d xor
    while
        dup h# 0a = if
            drop
        else
            over c! 1+
        then
    repeat
    drop swap -
;

: 3rd   >r over r> swap ;
: 3dup  3rd 3rd 3rd ;

: sameword ( c-addr u wp -- c-addr u wp flag )
    2dup d# 2 + c@ = if
        3dup
        d# 3 + >r
        bounds
        begin
            2dupxor
        while
            dup c@ r@ c@ <> if
                2drop rdrop false exit
            then
            1+
            r> 1+ >r
        repeat
        2drop rdrop true
    else
        false
    then
;

\ lsb 0 means non-immediate, return -1
\     1 means immediate,     return  1
: isimmediate ( wp -- -1 | 1 )
    uw@ d# 1 and 2* 1-
;

: sfind
    ll uw@
    begin
        dup
    while
        sameword
        if 
            nip nip
            dup
            d# 2 +
            count +
            d# 1 + d# -2 and
            swap isimmediate
            exit
        then
        uw@
    repeat
;

: digit? ( c -- u f )
   dup h# 39 > h# 100 and +
   dup h# 140 > h# 107 and - h# 30 -
   dup base @ u<
;

: ud* ( ud1 u -- ud2 ) \ ud2 is the product of ud1 and u
    tuck * >r
    um* r> +
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

header execute
: execute
    >r
;

header source
: source
    tib tib# @
;

\ From Forth200x - public domain

: isspace? ( c -- f )
    bl 1+ u< ;

: isnotspace? ( c -- f )
    isspace? 0= ;

: xt-skip   ( addr1 n1 xt -- addr2 n2 ) \ gforth
    \ skip all characters satisfying xt ( c -- f )
    >r
    BEGIN
    over c@ r@ execute
    over 0<> and
    WHILE
	d# 1 /string
    REPEAT
    r> drop ;

: parse-name ( "name" -- c-addr u )
    source >in @ /string
    ['] isspace? xt-skip over >r
    ['] isnotspace? xt-skip ( end-word restlen r: start-word )
    2dup d# 1 min + source drop - >in !
    drop r> tuck - ;

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

: xmain
    cr d# 1 ms cr
    d# 60 begin
        [char] - emit
    eol until
    begin key? while key drop repeat

    cr h# ffff hex8

    d# 0 d# 100 dump
    words cr cr

    begin again

    begin
        cr
        tib d# 30 accept >r
        d# 0. tib r> >number
        2drop hex4 space hex4
    again

    snap
;

: route
    r> + >r ;

\   (doubleAlso) ( c-addr u -- x 1 | x x 2 )
\               If the string is legal, leave a single or double cell number
\               and size of the number.

: isvoid ( caddr u -- ) \ any char remains, throw -13
    nip 0<>
    if [char] x emit snap then
;

: consume1 ( caddr u ch -- caddr' u' f )
    >r over c@ r> =
    over 0<> and
    dup>r d# 1 and /string r>
;

: (doubleAlso)
    h# 0. 2swap
    [char] - consume1 >r
    >number
    [char] . consume1 if
        isvoid              \ double number
        r> if dnegate then
        d# 2 exit
    then
                            \ single number
    isvoid drop
    r> if negate then
    d# 1
;

: doubleAlso
    (doubleAlso) drop
;


: dispatch
    route ;fallthru
    jmp execute                 \      -1      0       non-immediate
    jmp doubleAlso              \      0       0       number
    jmp execute                 \      1       0       immediate

\   jmp compile_comma           \      -1      2       non-immediate
\   jmp doubleAlso_comma        \      0       2       number
\   jmp execute                 \      1       2       immediate

: interpret
    begin
        parse-name dup
    while
        sfind 
        1+ 2* dispatch
    repeat
    2drop
;

: main
    2drop
    begin
        tib d# 80 accept
        tib# !
        \ h# 40 emit
        d# 0 >in !
        source dump
        \ cr parse-name sfind
        \ if
        \     execute
        \ then
        interpret
    again
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
    begin
        b.key d# 27 =
    until

    b.32 d# 0
    begin
        2dupxor
    while
        b.32 over !
        d# 4 +
    repeat
;

meta
    link @ t,
    link @ t' ll tw!
    there  t' dp tw!
target
