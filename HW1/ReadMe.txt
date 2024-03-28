(1) what you observe in Table 1 and how you find out all 256 functions for ROP3 in Part 3
觀察Table 1，可以發現Mode數值是由其對應的運算式，
將P、S和D帶入對應的數值後之運算結果，而P、S和D對應的數值分別為8'hF0、8'hCC和8'hAA。
舉例運算式P&S帶入P=8'hF0和S=8'hCC，便可以計算出其對應的Mode數值為(8'hF0&8'hCC)=8'C0。
由於8bits的Mode可以由1、2、4、8、16、32、64和128八組數值組合並經OR運算得到，
因此先查表找出這八組數值所對應的運算式，接著根據Mode各個bit的0或1，決定組合中包含哪些運算式，
最後將組合中的運算式經OR運算，便可得到該Mode所對應的運算結果。
舉例Mode=8'b01001010的第二、四和七bit為1，則其組合為2、8和64所對應的運算式，
因此Mode=8'b01001010的運算式為2、8和64的運算式OR在一起。

(2) how you organize your testbench to test your RTL design in Part 2 & Part 3
我使用五個for迴圈來產生所有可能的測試資料。
最外層的迴圈索引值i為mode_state，在part2中範圍為0~15，在part3中範圍則為0~256；
中間三層的迴圈索引值j、k和l分別為P、S和D的輸入值，範圍取決於其bit數`N；
最內層的迴圈則是循環三個clk，將P、S、D的數值透過Bitmap輸入ROP3。
結束最內層的迴圈，回到第四層的迴圈時，再比較兩個ROP3的結果是否正確。


 