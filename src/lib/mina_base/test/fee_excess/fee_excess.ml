open Core_kernel
open Currency
open Mina_base
open Snark_params.Tick
open Fee_excess

let combine_checked_unchecked_consistent () =
  Quickcheck.test (Quickcheck.Generator.tuple2 gen gen) ~f:(fun (fe1, fe2) ->
      let fe = combine fe1 fe2 in
      let fe_checked =
        Or_error.try_with (fun () ->
            Test_util.checked_to_unchecked
              Typ.(typ * typ)
              typ
              (fun (fe1, fe2) -> combine_checked fe1 fe2)
              (fe1, fe2) )
      in
      match (fe, fe_checked) with
      | Ok fe, Ok fe_checked ->
          [%test_eq: t] fe fe_checked
      | Error _, Error _ ->
          ()
      | _ ->
          [%test_eq: t Or_error.t] fe fe_checked )

let combine_succeed_with_0_middle () =
  Quickcheck.test
    Quickcheck.Generator.(
      filter (tuple3 gen Token_id.gen Fee.Signed.gen)
        ~f:(fun (fe1, tid, _excess) ->
          (* The tokens before and after should be distinct.
             Especially in this scenario, we may get an overflow error
             otherwise. *)
          not (Token_id.equal fe1.fee_token_l tid) ))
    ~f:(fun (fe1, tid, excess) ->
      let fe2 =
        if Fee.Signed.(equal zero) fe1.fee_excess_r then of_single (tid, excess)
        else
          match
            of_one_or_two
              (`Two
                ( (fe1.fee_token_r, Fee.Signed.negate fe1.fee_excess_r)
                , (tid, excess) ) )
          with
          | Ok fe2 ->
              fe2
          | Error _ ->
              (* The token is the same, and rebalancing causes an overflow. *)
              of_single (fe1.fee_token_r, Fee.Signed.negate fe1.fee_excess_r)
      in
      ignore @@ Or_error.ok_exn (combine fe1 fe2) )

let () =
  let open Alcotest in
  run "Test fee excesses."
    [ ( "fee-excess"
      , [ test_case "Checked and unchecked behaviour consistent." `Quick
            combine_checked_unchecked_consistent
        ; test_case "Combine succeeds when the middle excess is zero." `Quick
            combine_succeed_with_0_middle
        ] )
    ]
