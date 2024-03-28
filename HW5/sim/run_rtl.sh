
### part1: CONV1_DW ###
# vcs -R +v2k -full64 -f sim.f -debug_acc -l vcs_part1.log \
# +define+TEST_CONV1_DW+PAT_L=0+PAT_U=99 \
# +define+FLAG_VERBOSE=0 \
# +define+FLAG_SHOWNUM=0 \
# +define+FLAG_DUMPWV=0

### part2: CONV1_DW + CONV1_PW ###
# vcs -R +v2k -full64 -f sim.f -debug_acc -l vcs_part2.log \
# +define+TEST_CONV1_PW+PAT_L=0+PAT_U=99 \
# +define+FLAG_VERBOSE=0 \
# +define+FLAG_SHOWNUM=0 \
# +define+FLAG_DUMPWV=0

### part3: CONV1_DW + CONV1_PW + CONV2_DW + CONV2_PW ###
# vcs -R +v2k -full64 -f sim.f -debug_acc -l vcs_part3.log \
# +define+TEST_CONV2_PW+PAT_L=0+PAT_U=99 \
# +define+FLAG_VERBOSE=0 \
# +define+FLAG_SHOWNUM=0 \
# +define+FLAG_DUMPWV=0

### part4: CONV1_DW + CONV1_PW + CONV2_DW + CONV2_PW + CONV3 + POOL ###
vcs -R +v2k -full64 -f sim.f -debug_acc -l vcs_part4.log \
+define+TEST_CONV3_POOL+PAT_L=0+PAT_U=99 \
+define+FLAG_VERBOSE=0 \
+define+FLAG_SHOWNUM=1 \
+define+FLAG_DUMPWV=0


### Notice1: set FLAG_VERBOSE to 1 for detailed simulation reports
### Notice2: set FLAG_SHOWNUM to 1 for displaying the digit classification information
### Notice3: set FLAG_DUMPWV to 1 for dumping the fsdb waveform