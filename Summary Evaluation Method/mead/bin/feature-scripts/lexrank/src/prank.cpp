#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <assert.h>
#include <time.h>

#include <vector>

#include "prmain.h"

static double thisjumpp; /* Prob. of jumping this round */
static double nextjumpp; /* Prob. of jumping next round */
static FLOAT totalrank;

static int max_err_id;
static double last_error = 0.0;
static int loop = 0;
static double error;

static void compute_newr(int lo, int hi);
static void check_prob(FLOAT *probs);

FLOAT *doit(void) {
    int i,j;
    int total = 0;

    nextjumpp = 0.0;

    for (i = 0; i < minid; i++) {
      old_pr[i] = 0.0; 
    }

    double initial_prob = 1.0 / (N + .0);
    for (i = minid; i <= maxid; i++) {
      //no topic
      new_pr[i] = old_pr[i] = initial_prob; 
      nextjumpp += old_pr[i] * graph_nodes[i].out_random;
    }

////////////
    for (i = minid; i <= maxid; i++) {
		printf("0\t%d\t%f\n",i,new_pr[i]);
	}
////////////

    //if (debug) {
    if (1) {
      fprintf(proglog,"\t jump probability =%10.8lf\n",nextjumpp);
    } 

    for (i = 1; i <= 2000; i++) {
	time_t start, end;
	int result = 0;

        FLOAT *tmp = old_pr;
        old_pr = new_pr;
        new_pr = tmp;

	thisjumpp = nextjumpp; 
	nextjumpp = 0.0;
	totalrank = 0.0;

	error = 0.0;
	fprintf(proglog, "Iteration %d,", i);
	start = time(NULL);
	compute_newr(minid, maxid);

	/* copy over the new eigenrank values */
	end = time(NULL);

	total += (end - start);
        if (! result) {
	  fprintf(proglog, " time = %ds,  error = %g, error_id = %u, total_rank = %.5f\n", 
		  (int)(end - start), error, max_err_id, totalrank);
	  if (debug) {
	    check_prob(new_pr);
	    fprintf(proglog,"\t jump probability =%10.8lf\n",nextjumpp);
	  }
	  if (error < errorb) break;
	  if (error > last_error){
	    loop++;
	    last_error = error;
	  }
	} else {
	  fprintf(proglog, " time = %ds, ", (int)(end - start));
	  fputs(" aborted\n", proglog);
	  break;
	}
////////////
    for (int j = minid; j <= maxid; j++) {
		printf("%d\t%d\t%f\n",i,j,new_pr[j]);
	}
////////////
    }
    fprintf(proglog, "Time: %ds total, %gs average\n",
	    total, ((double)total)/i);
    return new_pr;
}

static void compute_newr(int lo, int hi) {
    int i;
    double localerror, localnextjumpp;
    FLOAT localtotalrank = 0.0;
    int local_max_err_id;

    time_t start, finish;

    start = time(NULL);
    localnextjumpp = localerror = 0;
    for (i = lo; i <= hi; i++) {

        double outsum = 0.0; /* Local sums for diff/same host edges */

	/* Print progress indication */
	if ((i % 10000000) == 0) fputc(',', proglog);

	/*************************************************************/
	
	  //normal pagerank
        std::vector<int>::iterator itr;
	std::vector<float>::iterator itr2;
	for(itr = graph_nodes[i].inlinks.begin(), itr2 = graph_nodes[i].inweights.begin(); itr !=  graph_nodes[i].inlinks.end(); itr++, itr2++){
		if (i==147) {
			printf ("watch: other old_pr: %f   inweight: %f\n", old_pr[*itr] , *itr2);
		}
          outsum += old_pr[*itr] * *itr2;
	}
	//No topic defined. So every i will get uniform jump probability
		if (i==147) {
			printf ("watch2: bias: %f  thisjump: %f\n",biases[i],thisjumpp);
		}
	outsum += biases[i] * thisjumpp;
		
	localnextjumpp += outsum * graph_nodes[i].out_random;
	new_pr[i] =  outsum;
	localtotalrank += outsum;
	
        double tmp;
	if(old_pr[i] > 0){
	  double tmp = fabs((double)(old_pr[i] - new_pr[i])) / old_pr[i];
	  if (localerror < tmp){
	    localerror = tmp;
	    local_max_err_id = i;
	  }
	}
    }
    finish = time(NULL);
    if (finish-start > 60)
      fprintf(stderr, "\n ***busy thread %d %d (%ds)\n", lo, hi, (int)(finish-start));
    if (error < localerror){
      error = localerror;
      max_err_id = local_max_err_id;
    }
    nextjumpp = localnextjumpp;
    totalrank = localtotalrank;
}

static void check_prob(FLOAT *probs) {
    int i;
    double total = 0.0;

    for (i = minid; i <= maxid; i++) {
        total += probs[i];
    }
    fprintf(proglog, "\tsum of probabilities = %10.8lf\n", total);
}

