////////////////////
/* INITIAL SETUP */
//////////////////
qui {
clear all
cap log close
set mem 4000m
set more off
cd "/users/panosprotopapas/desktop/GameTheory"
log using GameTheory, replace
}

///////////////////////
/* SIMULATION SETUP */
/////////////////////
qui {

*************************************************************
*                      ENTER VALUES                         *
*************************************************************
local monte=1 /* Set number of simulations */
local colleges=20 /* Set number of colleges */
local applicants=1000 /* Set total number of applicants */
local older=0.25 /* Percentage of applicants during wave 1 */
local weight=0.25 /* Weight given to wave 1 students' grade */
local seats=50 /* Number of places each college has */
*************************************************************
*************************************************************

local younger=`=1-`older''
local weight2=`=1-`weight''
local colleges2=`colleges'-1
}

//////////////////////////////////////////////////////
/* GENERATE EMPTY VALUES TO BE FILLED WITH RESULTS */
////////////////////////////////////////////////////
qui {
set obs `=`monte'' 
gen befextra=.
gen aftextra=.
gen extraeff=.
gen wave1unmatched=.
gen wave2unmatched=.
gen enviouscolleges=.
gen enviousstudents=.
save results, replace
clear
set obs `=`monte'*`colleges2''
gen grade=.
gen diff=.
save results2, replace
clear
set obs `=`monte'*`applicants''
gen students=.
gen count=.
save results3, replace
clear
set obs `=`monte'' 
gen mean=.
gen sdev=.
save extra, replace
clear
set obs `=`monte'' 
forvalues i=1(1)`colleges' {
gen seatsfilled`i'=.
}
save placefillness, replace
clear
}

/////////////////////////////////
/* MONTE CARLO PROCESS STARTS */
///////////////////////////////
forvalues w=1(1)`monte' {
qui {

////////////////////////////////////
/* CREATE TEMPORAL DATASET */
//////////////////////////////////
set obs `=`colleges'+1'
gen min=.
gen max=.
gen diff=.
save minmax, replace
clear


///////////////////////////////////////////////////////////////////////
/* HISTORICAL AVERAGE PERCENTILE SCORES - POSTED ENTRY REQUIREMENTS */
/////////////////////////////////////////////////////////////////////
forvalues i=1(1)`colleges2' {
local k=`=`colleges'-`i''
local j=`=(1/`colleges')*`k''
local z`i'=`=((50/3)* invnormal(`j'))+50'
local z`colleges'=0
local z0=101
}

////////////////////
/* WAVE 1 GRADES */
//////////////////
set obs `=`older'*`applicants''
gen wave1=rnormal(50,50/3)
replace wave1=100 if wave1>100
replace wave1=0 if wave1<0
gsort -wave1
save wave1, replace

///////////////////////////////
/* WAVE 1 PERCENTILE SCORES */
/////////////////////////////
_pctile wave1, nq(`colleges')
local r`=`colleges''=0
local r0=101
forvalues i=1(1)`colleges2' {
local r`=`colleges'-`i''=r(r`i')
}

////////////////////////////////////////////////////
/* GENERATE UNPOSTED 1ST WAVE ENTRY REQUIREMENTS */
//////////////////////////////////////////////////
forvalues i=1(1)`colleges2' {
local R`i'=`=(`weight'*`r`i'')+(`weight2'*`z`i'')'
}
local R0=101
local R`=`colleges''=0

////////////////////
/* WAVE 2 GRADES */
//////////////////
clear
set obs `=`younger'*`applicants''
gen wave2=rnormal(50,50/3)
replace wave2=100 if wave2>100
replace wave2=0 if wave2<0
gsort -wave2
save wave2, replace

////////////////////////////////////////////////////
/* GENERATE UNPOSTED 2ND WAVE ENTRY REQUIREMENTS */
//////////////////////////////////////////////////
append using wave1
replace wave2=wave1 if wave2==.
rename wave2 wave
_pctile wave, nq(`colleges')
local RR`=`colleges''=0
local RR0=101
forvalues i=1(1)`colleges2' {
local RR`=`colleges'-`i''=r(r`i')
}

///////////////////////////////////////////////////////////////////////////////////
/* CONSTRUCT COLLEGE VARIABLES TO BE FILLED IN WITH ACCEPTED APPLICANTS' GRADES */
/////////////////////////////////////////////////////////////////////////////////
forvalues i=0(1)`colleges' {
gen college`i'=.
}

////////////////////////////
/* MATCH WAVE 1 STUDENTS */
//////////////////////////
forvalues i=1(1)`colleges' {
forvalues j=1(1)`=`applicants'*`older'' {
local k=`=`j'+(`applicants'*`younger')'
count if college`=`i'-1'<101 
local A=r(N) /* How many students are enrolled in college i-1 */
count if college`=`i'-1'==wave & _n==`k'
local B=r(N) /* Is the student in question enrolled in college i-1 (1 if true) */
local C=`z`i'' /* Posted minimum entry grade for college i */
local D=`=`z`=`i'-1''' /* Posted minimum entry grade for college i-1 */
if `=`i'-2'>=0 {
local E=`=`z`=`i'-2''' 
}
else {
local E=101 /* Posted minimum entry grade for college i-2 */
}
local F=`=`R`=`i'-1''' /* Real minimum entry grade for college i-1 */
local G=`R`i'' /* Real minimum entry grade for college i */
count if college`i'<101 
local H=r(N) /* How many students are enrolled in college i */
replace college`i'=wave if (_n==`k' & wave>=`C' & wave>=`G' & wave<`D' & `H'<`seats') | ///
(_n==`k' & wave>=`C' & wave>=`G' & wave<`E' & `H'<`seats' & ///
(wave<`F' |  wave<`D' | (wave>=`D' & wave>=`F' & `A'>=`seats' & `B'==0 )))
/* Enroll if: 
i)Student applied at university as 1st choice AND university accepts him AND has free positions
OR 
ii)Student applied at university as 2nd choice (this is why the i-2 entry grade is used)
AND university accepts him AND has free positions AND [university i-1 didn't accept him for grade
OR no empty places reasons] */
}
}

/////////////////////////////////////////////////
/* REPORT NUMBER OF WAVE 1 STUDENTS UNMATCHED */
///////////////////////////////////////////////
gen unmatch=wave1
forvalues i=1(1)`colleges' {
replace unmatch=. if college`i'!=.
}
count if unmatch<101
save wave, replace
clear
use results
replace wave1unmatched=r(N) in `w'
save results, replace

////////////////////////////
/* MATCH WAVE 2 STUDENTS */
//////////////////////////
clear
use wave
forvalues i=1(1)`colleges' {
forvalues k=1(1)`=`applicants'*`younger'' {
count if college`=`i'-1'<101 
local A=r(N)
count if college`=`i'-1'==wave & _n==`k'
local B=r(N)
local C=`z`i'' 
local D=`=`z`=`i'-1'''
if `=`i'-2'>=0 {
local E=`=`z`=`i'-2''' 
}
else {
local E=101
}
local F=`=`RR`=`i'-1'''
local G=`RR`i''
count if college`i'<101 
local H=r(N)
replace college`i'=wave if (_n==`k' & wave>=`C' & wave>=`G' & wave<`D' & `H'<`seats') | ///
(_n==`k' & wave>=`C' & wave>=`G' & wave<`E' & `H'<`seats' & ///
(wave<`F' |  wave<`D' | (wave>=`D' & wave>=`F' & `A'>=`seats' & `B'==0) ))
}
}

/////////////////////////////////////////////////////////////
/* REGISTER NUMBER OF STUDENTS UNMATCHED (WAVE 2 & TOTAL) */
///////////////////////////////////////////////////////////
gen extra=wave
forvalues i=1(1)`colleges' {
replace extra=. if college`i'!=.
}
replace wave=extra
replace extra=. if wave1!=.
count if extra<101
save wave, replace
clear
use results
replace wave2unmatched=r(N) in `w'
replace befextra=r(N)+wave1unmatched in `w'
save results, replace

///////////////////////////////////////////////////////////////////////
/* MATCH LAST STUDENTS (3RD WAVE) - NOW REAL ENTRY GRADES ARE KNOWN */
/////////////////////////////////////////////////////////////////////
clear
use wave
forvalues i=1(1)`colleges' {
forvalues k=1(1)`applicants' {
if wave!=. & _n==`k' { /* Due to this if command the process becomes
much faster since the loop only takes place when needed, i.e. when
the student is actually unmatched */
count if college`=`i'-1'<101 
local A=r(N)
count if college`=`i'-1'<101 in `k'
local B=r(N)
/* Variables Z,X,C are needed to accomodate for students also applying
at their 3rd choice university */
if `=`i'-2'>=0 {
count if college`=`i'-2'<101
local Z=r(N)
count if college`=`i'-2'<101 in `k'
local X=r(N)
}
else {
local Z=0
local X=0
}
if `=`i'-3'>=0 {
local C=`=`RR`=`i'-3''' 
}
else {
local C=101
}
if `=`i'-2'>=0 {
local E=`=`RR`=`i'-2''' 
}
else {
local E=101
}
local F=`=`RR`=`i'-1'''
local G=`RR`i''
count if college`i'<101 
local H=r(N)
/* Now students know the actual, previously unposted, entry requirements. Therefore,
posted but not actual entry requirements are not used now */
replace college`i'=wave if (_n==`k' & wave>=`G' & wave<`F' & `H'<`seats') | ///
(_n==`k' & wave>=`G' & wave<`E' & `H'<`seats' & ///
(wave<`F' | (wave>=`F' & `A'>=`seats' & `B'==0) )) | ///
/* Below is the extra code to accomodate for students also applying in a 3rd
university during this final process */
(_n==`k' & wave>=`G' & wave<`C' & `H'<`seats' & ///
(wave<`F' | (wave>=`F' & `A'>=`seats' & `B'==0)) & ///
(wave<`E' | (wave>=`E' & `Z'>=`seats' & `X'==0)) )
}
}
}

///////////////////////////////////////////////////////////
/* REGISTER NUMBER OF STUDENTS UNMATCHED AFTER 3RD WAVE */
/////////////////////////////////////////////////////////
forvalues i=1(1)`colleges' {
replace extra=. if college`i'!=.
}
count if extra<101
save wave, replace
clear
use results
replace aftextra=r(N) in `w'
save results, replace
forvalues i=1(1)`colleges' {
clear
use wave
summ college`i'
clear
use placefillness
replace seatsfilled`i'=r(N) in `w'
save placefillness, replace
} 

//////////////////////////////////////////////////////////////////
/* REPORT NUMBER OF ENVIOUS COLLEGES AND THE GRADE DIFFERENCE  */
/* BETWEEN WORST STUDENT IT HAS AND BEST STUDENT IT COULD GET */
///////////////////////////////////////////////////////////////
clear
use wave
drop wave wave1 college0 unmatch extra
save temp2, replace
clear
use results2
forvalues i=1(1)`colleges2' {
replace grade=`RR`i'' in `=(`w'-1)*`colleges2'+`i''
}
save results2, replace
clear
forvalues i=1(1)`colleges' {
use temp2
local j=`=`i'+1'
summ college`i'
clear
use minmax
replace min=r(min) in `j'
replace max=r(max) in `i'
save minmax, replace
}
drop if _n==1
drop if _n==20
replace diff=max-min
replace diff=. if diff<=0
count if diff!=.
save minmax, replace
clear
use results
replace enviouscolleges=r(N) in `w'
save results, replace
clear
forvalues i=1(1)`colleges2' {
use minmax
local diff=diff in `i'
clear
use results2
replace diff=`diff' in `=(`w'-1)*`colleges2'+`i''
save results2, replace
}

/////////////////////////////////////////////////////////
/* REPORT NUMBER OF ENVIOUS STUDENTS AND THEIR GRADES */
///////////////////////////////////////////////////////
clear
use temp2
forvalues i=1(1)`colleges2' {
local j=`=`i'+1'
forvalues k=1(1)`seats' {
summ college`i'
local min=r(min)
summ college`j'
local max=r(max)
if `max'-`min'>0 {
replace college`i'=. if college`i'<`=`min'+0.0000001'
replace college`j'=`min' if college`j'>`=`max'-0.0000001'
/* I used a threshold of 0.0000001 in the two previous lines because for some
very strange (and time-consuming until I found about it) reason Stata would
refuse to work using just an equality. Maybe it's due to having too much data in 
memory or it's a bug in Stata11 which I'm using. Setting a threshold obviously
gives rise to the chance of deleting accidentally a different student but since
the threshold is so small the chanse is almost zero */
save temp2, replace
clear
use results3
replace students=`max' in `=(((`w'-1)*`applicants')+((`i'-1)*`seats')+`k')' 
save results3, replace
clear
use temp2
}
}
}
clear
use results3
count if students<101 & _n>`=((`w'-1)*`applicants')'


forvalues i=1(1)`colleges' {
local j=`=`i'-1'
replace count=`i' if students>=`RR`i'' & students<`RR`j'' & _n>`=((`w'-1)*`applicants')'
replace students=`RR`i'' if count==`i' & _n>`=((`w'-1)*`applicants')'
}
save results3, replace

clear
use results
replace enviousstudents=r(N) in `w'
save results, replace
clear
use wave
replace extra=unmatch if extra==.
summ extra
clear
use extra
replace mean=r(mean) in `w'
replace sdev=r(sd) in `w'
save extra, replace
clear
}
disp `w' /* Just to know how many iterations have been done */
}

//////////////////
/* FINAL FIXES */
////////////////
qui {
use results
replace extraeff=((befextra-aftextra)/befextra)
save results, replace
clear
use results2
replace grade=. if diff==.
save results2, replace
clear
use results3
save results5, replace
clear
set obs 1
forvalues i=1(1)`colleges' {
gen college`i'=.
}
save results4, replace
clear
forvalues i=1(1)`colleges' {
use results5
count if count==`i'
clear
use results4
replace college`i'=(r(N)/`monte')
save results4, replace
clear
}
}

//////////////
/* RESULTS */
////////////
qui {
clear
use results2
rename grade EntryRequirements
rename diff GradeDifference
scatter GradeDifference EntryRequirement, msize(tiny) nodraw saving(Graph1, replace)
clear
use results4
graph bar college1-college`colleges', nodraw saving(Graph2, replace)
clear
use results
}
summ
clear
use results5
summ
clear
use results3
summ
clear
use extra
summ
clear
use placefillness
summ

log close
