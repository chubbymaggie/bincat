(*
    This file is part of BinCAT.
    Copyright 2014-2017 - Airbus Group

    BinCAT is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or (at your
    option) any later version.

    BinCAT is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with BinCAT.  If not, see <http://www.gnu.org/licenses/>.
*)

%{
    module L = Log.Make(struct let name = "parser" end)

    let missing_item item section =
      (* error message printing *)
      L.abort (fun p -> p "missing %s in section %s\n" item section);;

    (* current library name *)
    let libname = ref "";;

    (* temporary table to store tainting rules on functions of a given library *)
    let libraries: (string, Config.call_conv_t option * ((string * Config.call_conv_t option * Config.taint_t option * Config.taint_t list) list)) Hashtbl.t = Hashtbl.create 7;;

    (* list of the npk filenames containing function headers *)
    let npk_headers = ref []

    (* current override address *)
    let override_addr = ref Z.zero

    (* function to apply to retrieve taint source *)
    let taint_fun = ref (fun () -> Taint.Src.new_src ())
      
    (* temporary table used to check that all mandatory elements are filled in the configuration file *)
    let mandatory_keys = Hashtbl.create 20;;

    let mandatory_items = [
      (MODE, "mode", "program");
      (CALL_CONV, "call_conv", "program");
      (MEM_SZ, "mem_sz", "program");
      (OP_SZ, "op_sz", "program");
      (STACK_WIDTH, "stack_width", "program");
      (ARCHITECTURE, "architecture", "program");
      (FORMAT, "format", "program");
      (FILEPATH, "filepath", "program");
      (ENTRYPOINT, "analyser_ep", "analyzer");
      (ANALYSIS, "analysis", "analyzer");
      (STORE_MCFA, "store_marshalled_cfa", "analyzer");
      (IN_MCFA_FILE, "in_marshalled_cfa_file", "analyzer");
      (OUT_MCFA_FILE, "out_marshalled_cfa_file", "analyzer");
    ];;

      List.iter (fun (k, kname, sname) -> Hashtbl.add mandatory_keys k (kname, sname, false)) mandatory_items;;

    let x86_mandatory_keys = Hashtbl.create 20;;

    let x86_mandatory_items =  [
      (SS, "ss");
      (DS, "ds");
      (CS, "cs");
      (ES, "es");
      (FS, "fs");
      (GS, "gs");
      (GDT, "gdt");
      (MEM_MODEL, "mem_model");
       ];;

    List.iter (fun (k, kname) -> Hashtbl.add x86_mandatory_keys k (kname, false)) x86_mandatory_items;;

    let armv7_mandatory_keys = Hashtbl.create 20;;
    let armv8_mandatory_keys = Hashtbl.create 20;;

      (** set the corresponding option reference *)
      let update_boolean optname opt v =
        match String.uppercase v with
        | "TRUE"  -> opt := true
        | "FALSE" -> opt := false
        | _       -> L.abort (fun p -> p "Illegal boolean value for %s option (expected TRUE or FALSE)" optname)

      (** update the register table in configuration module *)
      let init_register rname v = Config.register_content := (rname, v) :: !Config.register_content

      let update_mandatory key =
        let kname, sname, _ = Hashtbl.find mandatory_keys key in
        Hashtbl.replace mandatory_keys key (kname, sname, true);;

      let update_arch_mandatory_key tbl key =
         let kname,  _ = Hashtbl.find tbl key in
         Hashtbl.replace tbl key (kname, true);;

      let update_x86_mandatory key = update_arch_mandatory_key x86_mandatory_keys key;;
      let _update_armv7_mandatory key = update_arch_mandatory_key armv7_mandatory_keys key;;
      let _update_armv8_mandatory key = update_arch_mandatory_key armv8_mandatory_keys key;;

      (** check that the version matches the one we support *)
      let check_ini_version input_version =
    let supported_version = 4 in
    if input_version != supported_version then
      L.abort (fun p->p "Invalid configuration version: '%d', expected: '%d'" input_version supported_version);;

      (** footer function *)
      let check_context () =
        (* check whether all mandatory items are provided *)
        Hashtbl.iter (fun _ (pname, sname, b) -> if not b then missing_item pname sname) mandatory_keys;
        if !Config.analysis = Config.Forward Config.Bin then
          begin
            match !Config.architecture with
            | Config.X86 -> Hashtbl.iter (fun _ (pname, b) -> if not b then missing_item pname "x86") x86_mandatory_keys
            | Config.ARMv7 -> Hashtbl.iter (fun _ (pname, b) -> if not b then missing_item pname "ARMv7") armv7_mandatory_keys
            | Config.ARMv8 -> Hashtbl.iter (fun _ (pname, b) -> if not b then missing_item pname "ARMv8") armv7_mandatory_keys
          end;
        (* fill the table of tainting rules for each provided library *)
        let add_tainting_rules l (c, funs) =
          let c' =
            match c with
              None    -> !Config.call_conv
            | Some c' -> c'
          in
          let add (fname, c, r, args) =
            let c' =
              match c with
                None    -> c'
              | Some c' -> c'
            in
            Hashtbl.replace Config.tainting_rules (l, fname) (c', r, args)
          in
          List.iter add (List.rev funs)
        in
        Hashtbl.iter add_tainting_rules libraries;
    (* complete the table of function rules with type information *)
        List.iter (fun header ->
        try
          L.debug (fun p -> p "Open npk file [%s]" header);
          let p = TypedC.read header in
          List.iter (fun (s, f) ->
            L.debug (fun p -> p "  - loaded type for [%s]" s);
        Hashtbl.add Config.typing_rules s f.TypedC.function_type) p.TypedC.function_declarations
        with e -> L.exc e (fun p -> p "failed to load header %s" header)) !npk_headers
    ;;

    %}
%token EOF LEFT_SQ_BRACKET RIGHT_SQ_BRACKET EQUAL REG MEM STAR AT
%token CALL_CONV CDECL FASTCALL STDCALL AAPCS MEM_MODEL MEM_SZ OP_SZ STACK_WIDTH
%token ANALYZER INI_VERSION UNROLL FUN_UNROLL DS CS SS ES FS GS FLAT SEGMENTED STATE
%token FORMAT RAW MANUAL PE ELF ENTRYPOINT FILEPATH MASK MODE REAL PROTECTED
%token LANGLE_BRACKET RANGLE_BRACKET LPAREN RPAREN COMMA UNDERSCORE
%token GDT CUT ASSERT IMPORTS CALL U T STACK HEAP SEMI_COLON PROGRAM
%token ANALYSIS FORWARD_BIN FORWARD_CFA BACKWARD STORE_MCFA IN_MCFA_FILE OUT_MCFA_FILE HEADER
%token OVERRIDE TAINT_NONE TAINT_ALL SECTION SECTIONS LOGLEVEL ARCHITECTURE X86 ARMV7 ARMV8
%token ENDIANNESS LITTLE BIG
%token <string> STRING
%token <string> HEX_BYTES
%token <string> QUOTED_STRING
%token <Z.t> INT
%token TAINT
%start <unit> process
%%
(* in every below rule a later rule in the file order may inhibit a previous rule *)
  process:
      | s=sections EOF { s; check_context () }


    sections:
    | s=section            { s }
    | ss=sections s=section    { ss; s }

      section:
    | LEFT_SQ_BRACKET PROGRAM RIGHT_SQ_BRACKET p=program   { p }
    | LEFT_SQ_BRACKET STATE RIGHT_SQ_BRACKET  st=state       { st }
    | LEFT_SQ_BRACKET ANALYZER RIGHT_SQ_BRACKET a=analyzer   { a }
    | LEFT_SQ_BRACKET SECTIONS RIGHT_SQ_BRACKET s=data_sections   { s }
    | LEFT_SQ_BRACKET l=libname RIGHT_SQ_BRACKET lib=library { l; lib }
    | LEFT_SQ_BRACKET ASSERT RIGHT_SQ_BRACKET r=assert_rules { r }
    | LEFT_SQ_BRACKET IMPORTS RIGHT_SQ_BRACKET i=imports     { i }
    | LEFT_SQ_BRACKET OVERRIDE RIGHT_SQ_BRACKET o=overrides     { o }
    | LEFT_SQ_BRACKET ARMV7 RIGHT_SQ_BRACKET a=armv7_section     { a }
    | LEFT_SQ_BRACKET ARMV8 RIGHT_SQ_BRACKET a=armv8_section     { a }
    | LEFT_SQ_BRACKET X86 RIGHT_SQ_BRACKET x=x86_section     { x }

    overrides:
    |                     { () }
    | o=override l=overrides { o ; l }

    override:
    | a=override_addr EQUAL i = override_item { a ; i }

    override_addr:
    | a=INT  { override_addr := a }

    override_item:
    |                     { () }
    | tainting_reg_item { () }
    | tainting_reg_item SEMI_COLON override_item { () }
    | tainting_addr_item { () }
    | tainting_addr_item SEMI_COLON override_item { () }

    tainting_reg_item:
    | t=tainting_reg {
      try
        let l = Hashtbl.find Config.reg_override !override_addr in
        Hashtbl.replace Config.reg_override !override_addr (t::l)
      with Not_found -> Hashtbl.add Config.reg_override !override_addr [t] }

    tainting_addr_item:
    | c=tainting_addr {
      let (tbl, a, o) = c in
      try
    let l' = Hashtbl.find tbl !override_addr in
    Hashtbl.replace tbl !override_addr ((a, o)::l')
      with Not_found -> Hashtbl.add tbl !override_addr [(a, o)]
    }

    tainting_reg:
    | REG LEFT_SQ_BRACKET r=STRING RIGHT_SQ_BRACKET COMMA i=init { (r, (fun _ -> i)) }

    tainting_addr:
    | MEM LEFT_SQ_BRACKET r=repeat RIGHT_SQ_BRACKET COMMA i = init { Config.mem_override, r, i }
    | HEAP LEFT_SQ_BRACKET r=repeat RIGHT_SQ_BRACKET COMMA i = init { Config.heap_override, r, i }
    | STACK LEFT_SQ_BRACKET r=repeat RIGHT_SQ_BRACKET COMMA i = init { Config.stack_override, r, i }


      imports:
    |                     { () }
    | i=import l=imports  { i ; l }

      import:
    | a=INT EQUAL libname=STRING COMMA fname=QUOTED_STRING { Hashtbl.replace Config.import_tbl a (libname, fname) }

      npk:
    | { [] }
    | s=QUOTED_STRING { [ s ] }
    | s=QUOTED_STRING COMMA l=npk { s::l }

      libname:
    | l=STRING { libname := l; Hashtbl.add libraries l (None, []) }

    program:
    | p=program_item             { p }
    | p=program_item pp=program  { p; pp }

    program_item:
    | CALL_CONV EQUAL c=callconv { update_mandatory CALL_CONV; Config.call_conv := c }
    | OP_SZ EQUAL i=INT          {
      update_mandatory OP_SZ;
      try Config.operand_sz := Z.to_int i
      with _ -> L.abort (fun p -> p "illegal operand size: [%s]" (Z.to_string i))
    }
    | MEM_SZ EQUAL i=INT         {
      update_mandatory MEM_SZ;
      try Config.address_sz := Z.to_int i
      with _ -> L.abort (fun p -> p "illegal address size: [%s]" (Z.to_string i))
    }
    | STACK_WIDTH EQUAL i=INT    {
      update_mandatory STACK_WIDTH;
      try Config.stack_width := Z.to_int i
      with _ -> L.abort (fun p -> p "illegal stack width: [%s]" (Z.to_string i))
    }
    | MODE EQUAL m=mmode         { update_mandatory MODE ; Config.mode := m }
    | ARCHITECTURE EQUAL a=architecture  { update_mandatory ARCHITECTURE; Config.architecture := a }
    | FILEPATH EQUAL f=QUOTED_STRING     { update_mandatory FILEPATH; Config.binary := f }
    | FORMAT EQUAL f=format      { update_mandatory FORMAT; Config.format := f }

      format:
    | PE  { Config.PE }
    | ELF { Config.ELF }
    | RAW { Config.RAW }
    | MANUAL { Config.MANUAL }

    callconv:
    | CDECL    { Config.CDECL }
    | FASTCALL { Config.FASTCALL }
    | STDCALL  { Config.STDCALL }
    | AAPCS    { Config.AAPCS }

    mmode:
    | PROTECTED { Config.Protected }
    | REAL      { Config.Real }

    architecture:
    | X86   { Config.X86 }
    | ARMV7 { Config.ARMv7 }
    | ARMV8 { Config.ARMv8 }


    x86_section:
    | s=x86_item                { s }
    | s=x86_item ss=x86_section { s; ss }

    x86_item:
    | MEM_MODEL EQUAL m=memmodel { update_x86_mandatory MEM_MODEL; Config.memory_model := m }
    | CS EQUAL i=init            { update_x86_mandatory CS; init_register "cs" i }
    | DS EQUAL i=init            { update_x86_mandatory DS; init_register "ds" i }
    | SS EQUAL i=init            { update_x86_mandatory SS; init_register "ss" i }
    | ES EQUAL i=init            { update_x86_mandatory ES; init_register "es" i }
    | FS EQUAL i=init            { update_x86_mandatory FS; init_register "fs" i }
    | GS EQUAL i=init            { update_x86_mandatory GS; init_register "gs" i }
    | GDT LEFT_SQ_BRACKET i=INT RIGHT_SQ_BRACKET EQUAL v=INT { update_x86_mandatory GDT; Hashtbl.replace Config.gdt i v }


      memmodel:
    | FLAT  { Config.Flat }
    | SEGMENTED { Config.Segmented }

    armv7_section:
    |  { () }
    | ENDIANNESS EQUAL e=endianness { Config.endianness := e }

    endianness:
    | LITTLE { Config.LITTLE }
    | BIG { Config.BIG }

    armv8_section:
    |  { () }


      analyzer:
    | a=analyzer_item         { a }
    | a=analyzer_item aa=analyzer { a; aa }

      analyzer_item:
    | INI_VERSION EQUAL i=INT        { check_ini_version (Z.to_int i) }
    | UNROLL EQUAL i=INT         { Config.unroll := Z.to_int i }
    | FUN_UNROLL EQUAL i=INT         { Config.fun_unroll := Z.to_int i }
    | ENTRYPOINT EQUAL i=INT         { update_mandatory ENTRYPOINT; Config.ep := i }
    | CUT EQUAL l=addresses          { List.iter (fun a -> Config.blackAddresses := Config.SAddresses.add a !Config.blackAddresses) l }
    | LOGLEVEL EQUAL i=INT           { Config.loglevel := Z.to_int i }
    | LOGLEVEL modname=STRING EQUAL i=INT
                                     { Hashtbl.add Config.module_loglevel modname (Z.to_int i) }
    | ANALYSIS EQUAL v=analysis_kind { update_mandatory ANALYSIS; Config.analysis := v }
    | IN_MCFA_FILE EQUAL f=QUOTED_STRING       { update_mandatory IN_MCFA_FILE; Config.in_mcfa_file := f }
    | OUT_MCFA_FILE EQUAL f=QUOTED_STRING       { update_mandatory OUT_MCFA_FILE; Config.out_mcfa_file := f }
    | STORE_MCFA EQUAL v=STRING      { update_mandatory STORE_MCFA; update_boolean "store_mcfa" Config.store_mcfa v }
    | HEADER EQUAL npk_list=npk { npk_headers := npk_list }

      analysis_kind:
    | FORWARD_BIN  { Config.Forward Config.Bin }
    | FORWARD_CFA  { Config.Forward Config.Cfa }
    | BACKWARD { Config.Backward }

      data_sections:
    |  { () }
    | s=section_item ss = data_sections{ s ; ss }

      section_item:
    | SECTION LEFT_SQ_BRACKET name=STRING RIGHT_SQ_BRACKET EQUAL virt_addr=INT COMMA virt_size=INT COMMA raw_addr=INT COMMA raw_size=INT { Config.sections :=  (virt_addr, virt_size, raw_addr, raw_size, name)::(!Config.sections)  }

     addresses:
    | i=INT { [ i ] }
    | i=INT COMMA l=addresses { i::l }

    state:
    |                     { () }
    | s=state_item ss=state { s; ss }

      state_item:
    | REG LEFT_SQ_BRACKET r=STRING RIGHT_SQ_BRACKET EQUAL v=init    { init_register r v }
    | MEM LEFT_SQ_BRACKET m=repeat RIGHT_SQ_BRACKET EQUAL v=init    { Config.memory_content := (m, v) :: !Config.memory_content }
    | STACK LEFT_SQ_BRACKET m=repeat RIGHT_SQ_BRACKET EQUAL v=init  { Config.stack_content := (m, v)  :: !Config.stack_content }
    | HEAP LEFT_SQ_BRACKET m=repeat RIGHT_SQ_BRACKET EQUAL v=init   { Config.heap_content := (m, v) :: !Config.heap_content }

      repeat:
    | i=INT { i, 1 }
    | i=INT STAR n=INT { i, Z.to_int n }

      library:
    | l=library_item        { l }
    | l=library_item ll=library { l; ll }

      library_item:
    | CALL_CONV EQUAL c=callconv  { let funs = snd (Hashtbl.find libraries !libname) in Hashtbl.replace libraries !libname (Some c, funs)  }
    | v=fun_rule          { let f, c, a = v in let cl, funs = Hashtbl.find libraries !libname in Hashtbl.replace libraries !libname (cl, (f, c, None, a)::funs) }
    | r=argument EQUAL v=fun_rule { let f, c, a = v in let cl, funs = Hashtbl.find libraries !libname in Hashtbl.replace libraries !libname (cl, (f, c, Some r, a)::funs) }

      fun_rule:
    | f=STRING LANGLE_BRACKET c=callconv RANGLE_BRACKET a=arguments { f, Some c, List.rev a }
    | f=STRING  a=arguments                             { f, None, List.rev a }

      arguments:
    | arg_list = delimited (LPAREN, separated_list (COMMA, argument), RPAREN) { arg_list }

     argument:
    | UNDERSCORE { Config.No_taint }
    | AT     { Config.Addr_taint }
    | STAR   { Config.Buf_taint }

      assert_rules:
    |                               { () }
    | a=assert_rule aa=assert_rules { a ; aa }

     assert_rule:
    | U EQUAL LPAREN CALL a=INT RPAREN arg=arguments { Hashtbl.replace Config.assert_untainted_functions a arg }
    | T EQUAL LPAREN CALL a=INT RPAREN arg=arguments { Hashtbl.replace Config.assert_tainted_functions a arg }

    (* memory and register init *)
     init:
    | set_default_source_function c=tcontent            { None, c }
    | c=mcontent                    { Some c, []  }
    | c1=mcontent set_default_source_function c2=tcontent   { Some c1, c2 }


      mcontent:
    | s=HEX_BYTES { Config.Bytes s }
    | s=HEX_BYTES MASK m=INT    { Config.Bytes_Mask (s, m) }
    | m=INT         { Config.Content m }
    | m=INT MASK m2=INT { Config.CMask (m, m2) }

    tcontent:
    | o=one_tcontent { o }
    | srcs = taint_sources { srcs }
    
    one_tcontent:
    | s=HEX_BYTES { [Config.TBytes (s, !taint_fun())] }
    | s=HEX_BYTES MASK m=INT    {[Config.TBytes_Mask (s, m, !taint_fun())] }
    | t=INT         { 
      if Z.compare t Z.zero = 0 then [Config.Taint_none]
      else [Config.Taint (t, !taint_fun())] }
    | TAINT_ALL { [Config.Taint_all (!taint_fun ())] }
    | TAINT_NONE { [Config.Taint_none] }
    | t=INT MASK t2=INT { [Config.TMask (t, t2, !taint_fun())] }

    taint_sources:
    | set_source_function ts = one_tcontent { ts }
    | set_source_function ts = one_tcontent STAR tss = taint_sources { ts@tss }

    set_default_source_function:
    | TAINT { taint_fun := fun () -> Taint.Src.new_src () }

    set_source_function:
    | id=INT COMMA { taint_fun := fun () -> (Z.to_int id) }
    
