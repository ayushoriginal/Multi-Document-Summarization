from nltk.tokenize import sent_tokenize
import pandas as pd
import numpy as np
#with open("merge.txt") as myfile:
#    data="".join(line for line in myfile)

#s = sent_tokenize(data)
#print(s[176])



df=pd.read_csv("matrix.csv")
#dim = list(range(50, -1))
#df.drop(df.columns[dim], axis=1)
arr = df.as_matrix()

index =  ['0001', '0002','0003','0005', '0006','0007', '0008', '0010',
'0011', '0015', '0017', '0020',
'0022', '0024','0026','0027', '0028','0029', 
'0031', '0033', '0034','0036','0037', '0038', '0040',
'0042', '0044','0045', '0046','0047', '0048','0049', '0050',
'0051', '0053','0055', '0056','0059',
'1001', '1008','1009', '1013','1022', '1026',
'1031', '1032','1033', '1038','1043', '1050']

row=0
for num in index:
	prefix = "./d3";
	suffix = "t_raw";
	#if(int(num/10) == 0):
	#	prefix+="0";
	prefix+=num;
	name= "";
	name+=prefix
	name+=suffix;
	name+="/merge.txt";
	with open(name) as myfile:
		data="".join(line for line in myfile)
	s = sent_tokenize(data)
	print(s[0]) # Just printing the first sentence as a test
	print("--------------")
	prefix+=".txt"
	f1=open(prefix, 'w+')
	word_count=0
	i=0
	for (x,y), value in np.ndenumerate(arr):
		if (x==row):
			#print(s[value-1]);
			if(len(s)>value-1):
				#ss = ''.join(s[value-1])
				#word_count+=len(s.split(ss))
				word_count+=len(s[value-1].split())
				if word_count>100: # Break if summary> 100 words
					break;
				f1.write(s[value-1]);
				i=i+1;

				#if i>10: # Break after 10 sentences
					#break;
	row=row+1
	#print(arr)



	#print(prefix)


#f1=open('./summary.txt', 'w+')

#i=0
#for (x,y), value in np.ndenumerate(arr):
#	if x==0:
#		print(s[value-1]);
#		f1.write(s[value-1]);
#		i=i+1;
#		if i>25:
#			break;
#print(arr)