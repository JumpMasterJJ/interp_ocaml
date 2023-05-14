(* 
Substitution:

Nothing to do for integers:
i {v/x} = i


Just keep going through operations:
(e1 + e2) {v/x} = (e1 {v/x}) + (e2 {v/x})


Variables are where substitution really happens:
x {v/x} = v
y {v/x} = y


Defining substisution: let
(let y = e1 in e2) {v/x}
=
let y = (e1 {v/x}) in (e2 {v/x})

(let x = e1 in e2) {v/x}
=
let x = (e1 {v/x}) in e2


Substitution for functions (Capture-avoiding substitution):
(fun x -> e) {v/x} = fun x -> e
(fun y -> e) {v/x} = fun y -> (e {v/x})
  if  y is not in the free (no binding) variables of v

Wrong example:
let x = z in (fun z -> x)
->
(fun z -> x) {z/x}
=
(fun z -> z)

So, if ever about to capture a variable,
replace it with a fresh name:
About to capture z: (fun z -> x) {z/x}
Replace argument:   (fun z1 -> x) {z/x}

*)

(* 
SimPL BNF:

e ::= 
  | x | i | b
  | e1 bop e2
  | let x = e1 in e2
  | if e1 then e2 else e3
  | fun x -> e
  | e1 e2
  | (e1, e2)
  | fst e
  | snd e
  | Left e
  | Right e
  | match e with Left x1 -> e1
  | Right x2 -> e2


bop ::=  + | * | <=
i ::= integers
x ::= identifiers
b ::= true | false

v ::= 
  | i | b
  | fun x -> e
  | (v1, v2)
  | Left v
  | Right v
  | (|fun x -> e, env|)   // only used in function closure


env ::= <maps from identifier to values>

*)

(* 
Big eval:

v ==> v

e1 + e2 ==> v
  if  e1 ==> v1
  and e2 ==> v2
  and v is the result of primitive operation v1 + v2

x =/=> x'

let x = e1 in e2 ==> v2
  if  e1 ==> v1
  and e2 {v1/x} ==> v2

if e1 then e2 else e3 ==> v2
  if  e1 ==> true
  and e2 ==> v2

if e1 then e2 else e3 ==> v3
  if  e1 ==> false
  and e3 ==> v3
*)

(* 
Semantics:

e1 e2 -> e1' e2
  if  e1 -> e1'
    
v1 e2 -> v1 e2'
  if  e2 -> e2'

(fun x -> e) v2 -> e {v2/x}

(e1, e2) -> (e1', e2)
  if  e1 -> e1'

(v1, e2) -> (v1, e2')
  if  e2 -> e2'

fst (v1, v2) -> v1

snd (v1, v2) -> v2

Left e -> Left e'
  if  e -> e'

Right e -> Right e'
  if  e -> e'

match e with Left x1 -> e1 | Right x2 -> e2
->
match e' with Left x1 -> e1 | Right x2 -> e2
  if  e -> e'

match Left v with Left x1 -> e1 | Right x2 -> e2
->
e1 {v/x1}

match Right v with Left x1 -> e1 | Right x2 -> e2
->
e2 {v/x2}
*)

(* 
Substitution is mental model:

+ Easy way to think about computation
  - except capture aboidance!
+ Not a realistic model of machines
  - Code and data kept separate
  - Code not "edited" during computation
  - Data is kept in memory


Dynamic environment:

+ Maps variable name to valus in current scope
+ Implements a kind of lazy substitution

<env, e> ==> v :
<env, e> is a machine configuration,
which like current state of the machine as the program is executing.
We can consider [env] as memory, and [e] as program being evaluated.
*)


(* 
Variables:
<env, x> ==> env(x)


Let expressions:
<env, let x = e1 in e2> ==> v2
  if  <env, e1> ==> v1
  and <env[x |-> v1], e2> ==> v2

env[x |-> v] : extending env with x bound to v


Value:
<env, v> ==> v


Binary operators:
<env, e1 + e2> ==> v
  if  <env, e1> ==> v1
  and <env, e2> ==> v2
  and v is v1 + v2


If expressions:
<env, if e1 then e2 else e3> ==> v2
  if  <env, e1> ==> true
  and <env, e2> ==> v2

<env, if e1 then e2 else e3> ==> v3
  if  <env, e1> ==> false
  and <env, e3> ==> v3


Examples:
<{}, let x = 1 + 2 in x + x> ==> 6
  <{}, 1 + 2> ==> 3
    <{}, 1> ==> 1
    <{}, 2> ==> 2
    1 + 2 = 3
  <{x:3}, x + x> ==> 6
    <{x:3}, x> ==> 3
    <{x:3}, x> ==> 3
    3 + 3 = 6


Dynamic scope:
The body of a function is evaluated in
current environment at time function is called,
not old environment at time fucntion was defined.
<{x:2, f:(fun y -> x)}, f 0> ==> 2

Function and application:
<env, fun x -> e> ==> fun x -> e
<env, e1 e2> ==> v
  if  <env, e1> ==> fun x -> e
  and <env, e2> ==> v2
  and <env[x |-> v2], e> ==> v

Example with dynamic scope:
<{x:1, f:(fun y -> x)}, let x = 2 in f 0> ==> 2
  <{x:1, f:(fun y -> x)}, 2> ==> 2
  <{x:1, f:(fun y -> x), x:2}, f 0> ==> 2
    <{x:1, f:(fun y -> x), x:2}, f> ==> fun y -> x
    <{x:1, f:(fun y -> x), x:2}, 0> ==> 0
    <{x:1, f:(fun y -> x), x:2, y:0}, x> ==> 2


Lexical scope:
The body of a function is evaluated in
old environment at time fucntion was defined,
not current environment at time function is called.
<{x:2, f:(fun y -> x)}, f 0> ==> 1

Implement by function closure, that has two parts:
+ The code, an expression e
+ The environment env that was current when the function was defined

Function and application:
<env, fun x -> e> ==> (|fun x -> e, env|)
<env, e1 e2> ==> v
  if  <env, e1> ==> (|fun x -> e, defenv|)
  and <env, e2> ==> v2
  and <defenv[x |-> v2], e> ==> v

Example with lexical scope:
<{x:1, f:(|fun x -> e, {x:1}|)}, let x = 2 in f 0> ==> 1
  <{x:1, f:(|fun x -> e, {x:1}|)}, 2> ==> 2
  <{x:1, f:(|fun x -> e, {x:1}|)}, f 0> ==> 1
    <{x:1, f:(|fun x -> e, {x:1}|), x:2}, f> ==> (|fun x -> e, {x:1}|)
    <{x:1, f:(|fun x -> e, {x:1}|), 0> ==> 0
    <{x:1, y:0}, x> ==> 1


Pair expression:
<env, (e1, e2)> ==> (v1, v2)
  if  <env, e1> ==> v1
  and <env, e2> ==> v2

<env, fst e> ==> v1
  if  <env, e> ==> (v1, v2)

<env, snd e> ==> v2
  if  <env, e> ==> (v1, v2)


Constructor expression:
<env, Left e> ==> Left v
  if  <env, e> ==> v

<env, Right e> ==> Right v
  if  <env, e> ==> v


Pattern matching expression:
<env, match e with Left x1 -> e1 | Right x2 -> e2> => v1
  if  <env, e> ==> Left v
  and <env[x1 |-> v], e1> ==> v1

<env, match e with Left x1 -> e1 | Right x2 -> e2> => v2
  if  <env, e> ==> Right v
  and <env[x2 |-> v], e2> ==> v2
*)