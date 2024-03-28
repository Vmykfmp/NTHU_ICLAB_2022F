## ICLAB2022 HW2 Part1 VCS simulation script ##
# Note: You need to pass all simulation to get the full scores! 


# Module: Behavior model; Mode: encrypt; Pattern: PAT1
vcs -R +v2k -full64 -f sim.f +define+EN +define+PAT1 -debug_acc -l vcs_be_en_pat1.log

# Module: Synthesizable RTL code; Mode: encrypt; Pattern: PAT1
vcs -R +v2k -full64 -f sim.f -debug_acc -l vcs_rtl_en_pat1.log



