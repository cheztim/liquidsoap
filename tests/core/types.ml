open Type

let should_work t t' r =
  let t = make t in
  let t' = make t' in
  let r = make r in
  Printf.printf "Finding min for %s and %s\n%!" (to_string t) (to_string t');
  let m = Typing.sup ~pos:None t t' in
  Printf.printf "Got: %s, expect %s\n%!" (to_string m) (to_string r);
  Typing.(m <: r);
  Typing.(t <: m);
  Typing.(t' <: m)

let should_fail t t' =
  try
    ignore (Typing.sup ~pos:None (make t) (make t'));
    assert false
  with _ -> ()

let () =
  should_work (var ()).descr Ground.bool Ground.bool;
  should_work Ground.bool (var ()).descr Ground.bool;

  should_fail Ground.bool Ground.int;
  should_fail
    (List { t = make Ground.bool; json_repr = `Tuple })
    (List { t = make Ground.int; json_repr = `Tuple });

  let mk_meth meth ty t =
    Meth ({ meth; scheme = ([], make ty); doc = ""; json_name = None }, make t)
  in

  let m = mk_meth "aa" Ground.int Ground.bool in

  should_work m Ground.bool Ground.bool;

  let n = mk_meth "b" Ground.bool m in

  should_work m n m;

  let n = mk_meth "aa" Ground.int Ground.int in

  should_fail m n;

  let n = mk_meth "aa" Ground.bool Ground.bool in

  should_fail m n;

  ()

let () =
  (* 'a.{foo:int} *)
  let a = Lang.method_t (Lang.univ_t ()) [("foo", ([], Lang.int_t), "foo")] in

  (* {foo:int} *)
  let b = Lang.method_t Lang.unit_t [("foo", ([], Lang.int_t), "foo")] in

  Typing.(a <: b);

  match (snd (Type.split_meths a)).Type.descr with
    | Tuple [] -> ()
    | _ -> assert false

let () =
  (* 'a *)
  let ty = Lang.univ_t () in

  (* 'b.{foo:int} *)
  let t1 = Lang.method_t (Lang.univ_t ()) [("foo", ([], Lang.int_t), "foo")] in

  (* 'c.{gni:string} *)
  let t2 =
    Lang.method_t (Lang.univ_t ()) [("gni", ([], Lang.string_t), "gni")]
  in

  (* (ty:t1) *)
  Typing.(ty <: t1);
  Typing.(t1 <: ty);

  (* (ty:t2) *)
  Typing.(ty <: t2);
  Typing.(t2 <: ty)

let () =
  (* 'a where 'a is an orderable type *)
  let a = Type.var ~constraints:[Type.ord_constr] () in

  (* ['b] *)
  let b = Lang.list_t (Lang.univ_t ()) in

  Typing.(a <: b);

  assert (
    Type.Constraints.mem Type.ord_constr
      (match (demeth b).Type.descr with
        | List { Type.t = { Type.descr = Var { contents = Free v }; _ }; _ } ->
            v.Type.constraints
        | _ -> assert false))

let () =
  (* 'a *)
  let a = Lang.univ_t () in

  (* 'b.{foo:int} *)
  let b = Lang.method_t (Lang.univ_t ()) [("foo", ([], Lang.int_t), "foo")] in

  (* 'c where 'c is an orderable type *)
  let c = Type.var ~constraints:[Type.ord_constr] () in

  (* 'a <: 'b.{foo:int} *)
  Typing.(a <: b);

  (* 'b.{foo:int} <: 'c *)
  Typing.(b <: c);

  assert (
    Type.Constraints.mem Type.ord_constr
      (match (demeth b).Type.descr with
        | Var { contents = Free v } -> v.Type.constraints
        | _ -> assert false));

  assert (
    Type.Constraints.mem Type.ord_constr
      (match (demeth a).Type.descr with
        | Var { contents = Free v } -> v.Type.constraints
        | _ -> assert false))

let () =
  (* 'a *)
  let a = Lang.univ_t () in

  (* 'a? *)
  let nullable_a = Lang.nullable_t a in

  (* 'b where 'b is a num type *)
  let b = Type.var ~constraints:[Type.num_constr] () in

  (* 'a <: 'b *)
  Typing.(a <: b);

  try
    (* 'a? <: string *)
    Typing.(nullable_a <: Lang.string_t);
    assert false
  with Liquidsoap_lang.Repr.Type_error _ -> ()

let () =
  (* 'a *)
  let a = Lang.univ_t () in

  (* 'a.{foo:int} *)
  let a_meth = Lang.method_t a [("foo", ([], Lang.int_t), "foo")] in

  (* 'b where 'b is a num type *)
  let b = Type.var ~constraints:[Type.num_constr] () in

  (* 'a <: 'b *)
  Typing.(a <: b);

  try
    (* 'a.{foo:int} <: string *)
    Typing.(a_meth <: Lang.string_t);
    assert false
  with Liquidsoap_lang.Repr.Type_error _ -> ()