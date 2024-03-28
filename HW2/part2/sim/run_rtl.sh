## ICLAB2022 HW2 Part2 VCS simulation script ##
# Note: You need to pass all simulation to get the full scores! 


# Mode: encrypt; Pattern: PAT1
vcs -R +v2k -full64 -f sim.f +define+EN +define+PAT1 -debug_acc -l vcs_en_pat1.log

# Mode: encrypt; Pattern: PAT2
vcs -R +v2k -full64 -f sim.f +define+EN +define+PAT2 -debug_acc -l vcs_en_pat2.log


# Mode: decrypt; Pattern: PAT1
vcs -R +v2k -full64 -f sim.f +define+DE +define+PAT1 -debug_acc -l vcs_de_pat1.log

# Mode: decrypt; Pattern: PAT2
vcs -R +v2k -full64 -f sim.f +define+DE +define+PAT2 -debug_acc -l vcs_de_pat2.log

