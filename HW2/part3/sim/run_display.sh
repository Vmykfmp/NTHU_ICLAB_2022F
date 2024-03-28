
## ICLAB2022 HW2 Part3 VCS simulation script ##
# Note: You need to pass all simulation to get the full scores! 

# Mode: decrypt; Pattern: PAT2
vcs -R +v2k -full64 -f sim_display.f +define+PAT2 -debug_acc -l vcs_dis_pat2.log

# Mode: decrypt; Pattern: PAT3
vcs -R +v2k -full64 -f sim_display.f +define+PAT3 -debug_acc -l vcs_dis_pat3.log

