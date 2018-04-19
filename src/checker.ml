open Ast
open Unify

(* functions to check the number of premises *)
exception Premise_num_error of int * int

let get_error tab = function
    | Match (n1, n2) ->
            let tab = String.make tab '\t' in
            begin match n1.pos, n2.pos with
            | Real p1, Real p2 ->
                    tab ^ (print_info p1) ^ ": " ^
                    (print_node true n1) ^ " =/= " ^
                    (print_info p2 ^ ": ") ^
                    (print_node true n2) ^ "\n"
            | _ ->
                    (print_node true n1) ^ "\n" ^ tab ^ "doesn't match\n" ^
                    (print_node true n2) ^ "\n"
            end
    | Eos -> "End of solutions\n"

let check_deriv pattern exprs =
    try
        let pair_expr node expr = 
            let Expr(judg, _, _, _) = expr in
            (node, judg)
        in
        let constraints = List.map2 pair_expr pattern exprs in
        unify constraints
    with Invalid_argument _ ->
        raise (Premise_num_error (List.length exprs, List.length pattern))

let match_rule ast exprs rule =
    match rule with
    | APP1 ->
            (* premise: M -> N *)
            (* conclusion: M T -> N T *)
            let pattern = [
                judgement (meta "M", meta "N");
                judgement (app (meta "M", meta "T"),
                           app (meta "N", meta "T"))]
            in
            check_deriv pattern (exprs @ [ast])
    | APP2 ->
            (* this rule is actually 2 *)
            (* conditions on metavar are not yet supported *)

            (* premise: M -> N *)
            (* conclusion: v M -> v N :- M -> N *)
            let of_normal v = [
                        judgement (meta "M", meta "N");
                        judgement (app (v, meta "M"),
                                    app (v, meta "N"))]
            in 
            (* for v = free id *)
            let free = free_id (meta "ID") in
            let pattern1 = of_normal free in
            begin match check_deriv pattern1 (exprs @ [ast]) with
            | Sol s -> Sol s
            | Fail _ ->
                    (* for v = (\x.T) *)
                    let abs = labs (meta "T") in
                    let pattern2 = of_normal abs in
                    check_deriv pattern2 (exprs @ [ast])
            end
    | APPABS ->
            let pattern =
                (* conclusion: M N -> M[N] *)
                judgement (app (lamb (meta "M"), meta "N"),
                           mapp (meta "M", meta "N"))
            in
            check_deriv [pattern] [ast]
    | APPFULL ->
            let fid = free_id (meta "ID") in
            let m = meta "M" in
            let n = meta "N" in
            (* premise: M[freeid id] -> N[freeid id] *)
            (* conclusion: \M -> \N *)
            let pattern = [
                    judgement (lamb m, lamb n);
                    judgement (mapp (m, fid), mapp (n, fid))]
            in
            check_deriv pattern (ast :: exprs)

let rec check_ast ast =
    let Expr(judg, (Rule(rule, _)), exprs, pos) = ast in
    try
        let result = match_rule ast exprs rule in
        match result with
        | Sol _ ->
                ignore (check_premises exprs)
        | Fail f ->
                print_string (print_info pos);
                print_string (" in " ^ (rule_name rule) ^ ":\n" ^ (get_error 1 f))
    with
        Premise_num_error (given, expect) ->
                print_string (print_info pos);
                print_string
                (":\nPremises number mismatch: " ^
                (string_of_int (given - 1)) ^ " given, but " ^
                (string_of_int (expect - 1)) ^ " expected for the rule " ^
                (rule_name rule) ^ "\n")

and check_premises exprs =
    match exprs with
    | [] -> ()
    | h :: t -> check_ast h
