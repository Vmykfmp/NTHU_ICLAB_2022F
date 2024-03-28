import numpy as np

if __name__ == '__main__':

    # input
    pattern_sel = int(input('Enter the pattern you want to show (0 ~ 99):\n'))
    layer_sel = int(input('Enter the layer you want to show:\n0 for unshuffle,\n1 for conv1_dw,\n2 for conv1_pw,\n3 for conv2_dw,\n4 for conv2_pw,\n5 for conv3_pool\n'))
    
    if(pattern_sel<0 or pattern_sel>99):
        raise ValueError('Invalid pattern num!')

    if(layer_sel<0 or layer_sel>5):
        raise ValueError('Invalid layer selection!')

    # load the feature maps
    unshuffle = np.load('feature_map/{:04}_unshuffle.npy'.format(pattern_sel)).astype(np.int32)
    conv1_dw = np.load('feature_map/{:04}_conv1_dw.npy'.format(pattern_sel))
    conv1_pw = np.load('feature_map/{:04}_conv1_pw.npy'.format(pattern_sel))
    conv2_dw = np.load('feature_map/{:04}_conv2_dw.npy'.format(pattern_sel))
    conv2_pw = np.load('feature_map/{:04}_conv2_pw.npy'.format(pattern_sel))
    conv3_pool = np.load('feature_map/{:04}_conv3_pool.npy'.format(pattern_sel))

    if(layer_sel == 0): # unshuffle
        channel_sel = int(input('Enter the channel you want to show (0 ~ 3): \n'))
        if(channel_sel >=0 and channel_sel <=3):
            print(unshuffle[int(channel_sel)])
        else: # 
            raise ValueError('Invalid channel number!')
    elif(layer_sel == 1): # conv1_dw
        channel_sel = int(input('Enter the channel you want to show (0 ~ 3): \n'))
        if(channel_sel >=0 and channel_sel <=3):
            print(conv1_dw[int(channel_sel)])
        else:
            raise ValueError('Invalid channel number!')
    elif(layer_sel == 2): # conv1_pw
        channel_sel = int(input('Enter the channel you want to show (0 ~ 3): \n'))
        if(channel_sel >=0 and channel_sel <=3):
            print(conv1_pw[int(channel_sel)])
        else:
            raise ValueError('Invalid channel number!')
    elif(layer_sel == 3): # conv2_dw
        channel_sel = int(input('Enter the channel you want to show (0 ~ 3): \n'))
        if(channel_sel >=0 and channel_sel <=3):
            print(conv2_dw[int(channel_sel)])
        else:
            raise ValueError('Invalid channel number!')
    elif(layer_sel == 4): # conv2_pw
        channel_sel = int(input('Enter the channel you want to show (0 ~ 11): \n'))
        if(channel_sel >=0 and channel_sel <=11):
            print(conv2_pw[int(channel_sel)])
        else:
            raise ValueError('Invalid channel number!')
    elif(layer_sel == 5): # conv3_pool
        channel_sel = int(input('Enter the channel you want to show (0 ~ 63): \n'))
        if(channel_sel >=0 and channel_sel <=63):
            print(conv3_pool[int(channel_sel)])
        else:
            raise ValueError('Invalid channel number!')
    else:
        raise ValueError('Invalid layer number!') 