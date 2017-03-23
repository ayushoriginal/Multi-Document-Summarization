#include <stdlib.h>
#include <stdio.h>
#include <string>
#include <map>
#include <sys/types.h>
#include <dirent.h>
#include <vector>
#include <math.h>

using namespace std;

double *global_model;

string inputfile;
string model_file;
double mu;

int main(int argc, char *argv[]) {

inputfile = argv[1];
model_file = argv[2];
mu = atof(argv[3]);
int Ndoc = atoi(argv[4]);
int Nterm = atoi(argv[5]);

global_model = (double *) malloc (Nterm * sizeof(double));

FILE *fp = fopen (model_file.c_str(), "r");
int id;
double val;
while (fscanf(fp,"%d\t%lf\n", &id, &val) != EOF)
	global_model[id] = val;
fclose (fp);


int *sizes = (int *) calloc (Ndoc , sizeof(int));
double *default_probs = (double *) calloc (Ndoc , sizeof(double));
vector<int> **model_ids = (vector<int> **) malloc (Ndoc * sizeof(vector<int> *));
vector<int> **model_tfs = (vector<int> **) malloc (Ndoc * sizeof(vector<int> *));
vector<double> **model_probs = (vector<double> **) malloc (Ndoc * sizeof(vector<double> *));

for (int i = 0; i < Ndoc; i++) {
	model_ids[i] = new vector<int>;
	model_tfs[i] = new vector<int>;
	model_probs[i] = new vector<double>;
}

  fp = fopen (inputfile.c_str(), "r");

  int d_id, t_id, tf; 

  while (fscanf(fp, "%d\t%d\t%d\n", &d_id, &t_id, &tf) != EOF) {
	(*model_ids[d_id]).push_back(t_id);
	(*model_tfs[d_id]).push_back(tf);
    sizes[d_id] += tf;
  }

  fclose(fp);

for (int i = 0; i < Ndoc; i++) {
	 for (int j = 0; j < (*model_ids[i]).size(); j++)
		(*model_probs[i]).push_back(((*model_tfs[i])[j] + mu*global_model[(*model_ids[i])[j]]) /
									(sizes[i] + mu));
 	 default_probs[i] = mu / (sizes[i]+mu);
}
  


for (int j=0; j < Ndoc; j++) {
  for (int i=0; i < Ndoc; i++) {
  if (j != i) {
      double gen_prob = 1;
	  int m=0,k=0;
	  while (m < (*model_ids[j]).size() && k < (*model_ids[i]).size()) {
		  if ((*model_ids[j])[m] < (*model_ids[i])[k]) {
			  gen_prob *= pow(default_probs[i] * global_model[(*model_ids[j])[m]],
							 ((*model_tfs[j])[m]+0.0) / sizes[j]);
			  m++;
		  }
		  else if ((*model_ids[j])[m] > (*model_ids[i])[k]) {
			  k++;
		  }
		  else {
			  gen_prob *= pow((*model_probs[i])[k],
							 ((*model_tfs[j])[m]+0.0) / sizes[j]);
			  m++; k++;
		  }
	  }
	  for (; m < (*model_ids[j]).size(); m++) {
		  gen_prob *= pow(default_probs[i] * global_model[(*model_ids[j])[m]],
						 ((*model_tfs[j])[m]+0.0) / sizes[j]);
	  }

    if (gen_prob > 0.0) {
	  printf ("%d %d %.10lf\n",j,i,gen_prob);
    }
  }
  }
}

return 0;
}
