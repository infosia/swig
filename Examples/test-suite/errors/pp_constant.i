%module xxx

/* Test preprocessor comments and their effect on line number reporting on later errors */

#define A1 1234
#define A2 1234 /*C comment*/
#define A3 1234

%constant int aaa=;

#define B1 1234
#define B2 1234 //C++ comment
#define B3 1234

%constant int bbb=;

#define C1 1234
#define C2 1234 /*multiline
C 
comment */
#define C3 1234

%constant int ccc=;

#define D1 1234
#define /*C Comment*/ D2 1234
#define D3 1234

%constant int ddd=;

#define E1 1234
#/*C comment*/define E2 1234
#define E3 1234

%constant int eee=;

#define F1 1234
#define F2 1234 \
// C comment
#define F3 1234

%constant int fff=;
