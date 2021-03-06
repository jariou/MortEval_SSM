data mort;    /* read dataset into SAS */
input Country$  Year  Age  Female Male  Total @@;   /* give name for each column */
lfr = log(Female);  /* take log calculation for last three column */
lmr = log(male);
lmt = log(total);
array ageArray{110} a1-a110; /* create dummy variables by an array to simplify the code part for age */
do i=1 to 110;
     ageArray[i] = (age=i);  
end;

datalines; /* input data according to above structure*/
DEU    2013    109    0.929799    2.566667    1.011348
DEU    2013    110     1.417293    6    1.485185
; /* remove most (99.99%) of datalines input to clearly show the code, and only keep two lines as example */


/*
proc freq data=mort;
   where Country='AUS';
   table age;
run;
proc freq data=mort;
   where Country='DNK';
   table age;
run;
proc freq data=mort;
   where Country='DEU';
   table age;
run;
*/ /* meaning of this part?? */


data aus;  /* extract aus data from mort */
  set mort;
  where Country='AUS';
run;
data dnk;  /* extract dnk data from mort */
  set mort;
  where Country='DNK';
run;
data deu;  /* extract deu data from mort */
  set mort;
  where Country='DEU';
run;

proc sort data=deu;  /* sort the deu data by year and age */
   by year age;
run;


proc iml; /* interactive matrix language */
    use deu;
    read all var {age} into x;  /* read age variable into x */
    bsp = bspline(x, 2, ., 4);  /* generate B-spline basis for a cubic spline with 4 evenly spaced internal knots in the x-range 
    (B-spline on x with degree=2 and number of knots = 4 and produce 7 variables) */
    create spline var{c1 c2 c3 c4 c5 c6 c7};  /* create a merged date set spline to contain spline basis columns (7 variables from last step) */
    append from bsp;
 quit;

 data deu; /* merge spline to data deu */
    merge deu spline;
 run;

%macro makeTerm;  /* tricky part: create a term equivalent to a1 + a2 +...+a110 */
   %do i=1 %to 110;
      %str( a&i + )
   %end;
%mend;
%let term = %makeTerm;


proc ssm data=deu plot=ao; /* ao: create a panel of plots consisting of prediction error normality plots */
  id year;
  parms v1-v7 0.001; /* parameters needed for state space model, and specify the initial values of v1-v7 as 0.001 */
  lambda = v1*c1 + v2*c2 + v3*c3 + v4*c4
       + v5*c5 + v6*c6 + v7*c7;  /* compute lambda via spline basis and latent variables (unobserved parameters) */
  if age=0 then lambda=1;
  parms lvar2;  /* create parameter lvar2 and optimised by grid searching */
  parms av1-av7;  /* parameters av1-av7 needed to define the variance function of this model*/
  var1 = exp(av1*c1 + av2*c2 + av3*c3 + av4*c4
       + av5*c5 + av6*c6 + av7*c7); /* define the variance function of this model */
  
  var2 = exp(lvar2); /* compute var2 as exponential of lvar2 */
  state slate(1) T(I) W(I) cov(d)=(var2) A1(1); /* define the state structure slate(1) with transition 
  matrix T(I) as identity form, design matrix W(I)as identity form, disturbance covariance Q as the diagonal 
  matrix cov(d) of taking var2 as diagonal and A1(1) defining the last element of the state subsection as diffuse*/
  comp beffect = (lambda)*slate[1]; /* define component beffect as the product of lambda and the first variabable from slate(1) */
  comp latent = slate[1]; /* define component latent as the first variabale from slate(1) */
  
  irregular wn variance=var1; /* define the observation noise with the variance function var1 */
  model lmr = a1-a110 beffect wn; /* model statement: regression part of a1-a110 + state part beffect + observation noise(residuals) */
  eval mpattern = &term beffect; /* define a variable mpattern as a1 + a2 +...+a110 + beffect */
  output out=deuFor press pdv; /* output is saved in deuFor, and press means print the prediction error sum of 
  squares, PDV means print inclusive of the variables defined in programming statements in SSM procedure */
run;

proc sgplot data=deuFor;
   where age=10;
   series x=year y=smoothed_beffect;
run;
proc sgplot data=deuFor;
   where year=2000;
   series x=age y=lambda;
run;

proc sgplot data=deuFor;
   where age=10;
   series x=year y=smoothed_latent;
run;

proc sgplot data=deuFor;
   where age=10;
   series x=year y=smoothed_mpattern;
   scatter x=year y= lmr;
run;

proc iml;
    use dnk;
    read all var {age} into x;
    bsp = bspline(x, 2, ., 4);
    create spline var{c1 c2 c3 c4 c5 c6 c7};
    append from bsp;
 quit;
 data dnk;
    merge dnk spline;
 run;
proc ssm data=dnk plot=ao;
  id year;
  parms v1-v7 0.001;
  lambda = v1*c1 + v2*c2 + v3*c3 + v4*c4
       + v5*c5 + v6*c6 + v7*c7;
  if age=0 then lambda=1;
  parms lvar2;
  parms av1-av7;
  var1 = exp(av1*c1 + av2*c2 + av3*c3 + av4*c4
       + av5*c5 + av6*c6 + av7*c7);
  
  var2 = exp(lvar2);
  state slate(1) T(I) W(I) cov(d)=(var2) A1(1);
  comp beffect = (lambda)*slate[1];
  comp latent = slate[1];
  
  irregular wn variance=var1;
  model lmr = a1-a110 beffect wn;
  eval mpattern = &term beffect;
  output out=dnkFor press pdv;
run;

proc iml;
    use aus;
    read all var {age} into x;
    bsp = bspline(x, 2, ., 4);
    create spline var{c1 c2 c3 c4 c5 c6 c7};
    append from bsp;
 quit;
 data aus;
    merge aus spline;
 run;
proc ssm data=aus plot=ao;
  id year;
  parms v1-v7 0.001;
  lambda = v1*c1 + v2*c2 + v3*c3 + v4*c4
       + v5*c5 + v6*c6 + v7*c7;
  if age=0 then lambda=1;
  parms lvar2;
  parms av1-av7;
  var1 = exp(av1*c1 + av2*c2 + av3*c3 + av4*c4
       + av5*c5 + av6*c6 + av7*c7);
  
  var2 = exp(lvar2);
  state slate(1) T(I) W(I) cov(d)=(var2) A1(1);
  comp beffect = (lambda)*slate[1];
  comp latent = slate[1];
  
  irregular wn variance=var1;
  model lmr = a1-a110 beffect wn;
  eval mpattern = &term beffect;
  output out=ausFor press pdv;
run;