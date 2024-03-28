# Rank A
vcs -f hdl.f -full64 -R -debug_access+all +v2k \
+define+RANK_A+PAT_L=0+PAT_U=299

# Rank B
vcs -f hdl.f -full64 -R -debug_access+all +v2k \
+define+RANK_B+PAT_L=0+PAT_U=99

# Rank C
vcs -f hdl.f -full64 -R -debug_access+all +v2k \
+define+RANK_C+PAT_L=0+PAT_U=99

# Rank D
vcs -f hdl.f -full64 -R -debug_access+all +v2k \
+define+RANK_D+PAT_L=0+PAT_U=99