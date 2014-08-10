/* create library Fitness */
libname clus "C:\Users\Ivan.Liuyanfeng\Desktop\Data_Mining_Work_Space\Bank_clients_cluster";

/* redirect log to handle the log limitations */
proc printto log="C:\Users\Ivan.Liuyanfeng\Desktop\Data_Mining_Work_Space\Bank_clients_cluster\two_steps_cluster.log";
run;

options user=clus;
ods pdf file = 'C:\Users\Ivan.Liuyanfeng\Desktop\Data_Mining_Work_Space\Bank_clients_cluster\two_steps_cluster.pdf';

/***1.data explo***/

/***1.1 obtain the # of var***/
proc contents data=clus.banktr noprint out=clus.p;
run;

proc sql;
select name into:var separated by ' '
from p
;
quit;

%put &var;

/****1.2 compress var by principal components analysis***/

proc princomp data=clus.banktr out=clus.out_prin;
var &var;
run;

/****1.3 adjust MAXEIGEN value by PCA*/
proc varclus data=clus.banktr MAXEIGEN=0.75 outtree=fortree;
var &var;
run;


/***1.4 confirm the final # of var****/
%let input=ddatot savbal income invest atmct atres adbdda;

/***1.5 Range standardization transformation***/
proc stdize data=clus.banktr(keep=&input) method=range 
outstat=stat_out out=out_std;
var &input;
run;

/****2.Initial cluster****/

/***2.1 fast cluster***/
proc fastclus data=out_std maxc=50 out=out_fstcl outstat=fst_out drift;
var  &input ;
run;

/***2.2 obtain mean*/
proc means data=out_fstcl nway;
class CLUSTER;
var &input;
output out=out_mean mean=;
run;

/****2.3 second cluster by WARD***/
proc cluster data=out_mean(keep=&input  CLUSTER rename=(CLUSTER=CLUSTER1)) 
ccc pseudo method=ward outtree=fortree2;
var &input;
copy CLUSTER1 ;
run;

/***2.4 compare CCC;PSEUDO value***/
proc tree data=fortree2 level=0.008 out=tree;
run;

proc tree data=fortree2 nclusters=8 out=out_tree;
copy CLUSTER1 ;
run;


proc sql;
	create table result as
	select a.*,b.cluster as big_clus,
	1 as flag
	from out_fstcl as a
	left join out_tree as b
	  on a.cluster = b.cluster1
	;
quit;


/*****2.Model validation****/

/***2.1 standardization***/
proc stdize data=clus.bankte(keep=&input) method=in(stat_out) out=score_std;
run;

/***2.2fast cluster***/
proc fastclus data=score_std instat=fst_out out=score_fst;
run;

/***2.3 results****/
proc sql;
create table dis_clu as
select distinct
big_clus,cluster
from result;
quit;

proc sql;
create table score_result as
select
b.*,
a.big_clus,
2 as flag	
from dis_clu as a
join score_fst as b
on a.cluster=b.cluster
;
quit;

/****3.NABIVA***/

/***3.1 training data***/
proc means data=result nway;
class big_clus;
var &input;
output out=train_mean mean=;
run;

/**3.2 testing data**/
proc means data=score_result nway;
class big_clus;
var &input;
output out=valid_mean mean=;
run;

/**3.4 training manova****/
proc glm data=result;
class big_clus;
model &input=big_clus/;
means big_clus;
  manova h = _all_;
run;
quit;

/**3.4 testing manova****/
proc glm data=score_result;
class big_clus;
model &input=big_clus/;
means big_clus;
  manova h = _all_;
run;
quit;


/**/
/*/***3.5 manova of train and test**/*/
/*%macro com(num);*/
/*data comp ;*/
/*set result(where=(big_clus=&num)) score_result(where=(big_clus=&num));*/
/*run;*/
/**/
/*proc glm data=comp;*/
/*class flag;*/
/*model &input=flag/solution nouni;*/
/*means flag / tukey;*/
/*	manova h = _all_;*/
/*run;*/
/*quit;*/
/*%mend com;*/
/**/
/*%com(1);*/
/*%com(2);*/
/*%com(3);*/
/*%com(4);*/
/*%com(5);*/
/*%com(6);*/
/*%com(7);*/
/*%com(8);*/

/**/
/****4.migration***/

data migr1;
set result(obs=1000 keep=big_clus rename=(big_clus=pvt_clus));
run;

data migr2;
set score_result(keep=big_clus rename=(big_clus=lst_clus));
run;

data migr;
merge migr1 migr2;
run;

proc freq data=migr;
table pvt_clus*lst_clus/NOPERCENT NOCOL NOROW chisq;
run;

ods pdf close;



