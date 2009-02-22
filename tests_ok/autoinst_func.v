module autoinst_func;
   
   /*AUTO_LISP(defun testfunc (sig bits) (let ((result "{"))
    (setq result (concat result sig "[0" bits "]"))
    (concat result "}")))*/
   
   /* autoinst_wildcard_sub AUTO_TEMPLATE (
    .sd0_adrs@          (myport@"(substring \\"\1\\" 0 1)"),
    .\(.*\)                     (@"(testfunc vl-name vl-bits)"),
    ); */
   
   autoinst_wildcard_sub sub0
     (/*AUTOINST*/
      // Inouts
      .sd_ras_                          ({sd_ras_[0]}),          // Templated 9
      .sd0_dqm7_l                       ({sd0_dqm7_l[0]}),       // Templated 9
      .sd0_dqm6_l                       ({sd0_dqm6_l[0]}),       // Templated 9
      .sd0_dqm5_l                       ({sd0_dqm5_l[0]}),       // Templated 9
      .sd0_dqm4_l                       ({sd0_dqm4_l[0]}),       // Templated 9
      .sd0_dqm3_l                       ({sd0_dqm3_l[0]}),       // Templated 9
      .sd0_dqm2_l                       ({sd0_dqm2_l[0]}),       // Templated 9
      .sd0_dqm1_l                       ({sd0_dqm1_l[0]}),       // Templated 9
      .sd0_dqm0_l                       ({sd0_dqm0_l[0]}),       // Templated 9
      .sd0_ba1                          ({sd0_ba1[0]}),          // Templated 9
      .sd0_ba0                          ({sd0_ba0[0]}),          // Templated 9
      .sd0_adrs11                       (myport1),               // Templated 8
      .sd0_adrs10                       (myport1),               // Templated 8
      .sd0_adrs9                        (myport9),               // Templated 8
      .sd0_adrs8                        (myport8),               // Templated 8
      .sd0_adrs7                        (myport7),               // Templated 8
      .sd0_adrs6                        (myport6),               // Templated 8
      .sd0_adrs5                        (myport5),               // Templated 8
      .sd0_adrs4                        (myport4),               // Templated 8
      .sd0_adrs3                        (myport3),               // Templated 8
      .sd0_adrs2                        (myport2),               // Templated 8
      .sd0_adrs1                        (myport1),               // Templated 8
      .sd0_adrs0                        (myport0),               // Templated 8
      .sd0_clk                          ({sd0_clk[0]}));                 // Templated 9
   
endmodule

// Local Variables:
// verilog-auto-inst-template-numbers: t
// End:
