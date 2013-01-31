/*
 * get.c
 *
 * Wrapper of the MatLab Engine API engGetVariable
 * for call from Mathematica
 *
 * Revision 2003.3.11
 *
 * Robert
 *	
 */

#include "mengine.h"

#include <stdlib.h>		// for malloc() & free()
#include <string.h>


// Takes a MATLAB variable and writes in in Mathematica form to link
// To be used with loopback links
// Returns 0 on success
// Returns 1 on failure and may leave the link with a half-built expression
void toMma(const mxArray *matlabVar, MLINK link) {
	mwSize        depth;
	const mwSize *matlabDims;
	int          *mmaDims;

	int i;

	//retrive size information
	depth = mxGetNumberOfDimensions(matlabVar);
	matlabDims = mxGetDimensions(matlabVar);

	for (i = 0; i < depth; ++i) {
		if (matlabDims[i] == 0) {
			MLPutFunction(link, "List", 0);	// temporary workaround for empty array, just return {};  TODO fix
			return;
		}
	}

	//translate dimension information to Mathematica
	mmaDims = malloc(depth * sizeof(int));
	for(i = 0; i < depth; ++i)
		mmaDims[i] = matlabDims[depth - 1 - i];

	// numerical; TODO handle single precision and other types
	if (mxIsDouble(matlabVar)) {
		double *Pr = NULL;	//pointer to real
		double *Pi = NULL;	//pointer to imaginary

		//data pointer
		Pr = mxGetPr(matlabVar);
		Pi = mxGetPi(matlabVar);

		MLPutFunction(link, "matArray", 2);
		if (mxIsComplex(matlabVar)) {
			//output re+im*I
			MLPutFunction(link, "Plus", 2);
			MLPutReal64Array(link, Pr, mmaDims, NULL, depth);
			MLPutFunction(link, "Times", 2);
			MLPutReal64Array(link, Pi, mmaDims, NULL, depth);
			MLPutSymbol(link, "I");
		}
		else {
			MLPutReal64Array(link, Pr, mmaDims, NULL, depth);
		}
		MLPutInteger32List(link, mmaDims, depth);
	}
	// char array (string); TODO handle multidimensional char arrays
	else if (mxIsChar(matlabVar)) {
		char *str;

		str = mxArrayToString(matlabVar);
		MLPutFunction(link, "matString", 1);
		MLPutUTF8String(link, (unsigned char *) str, strlen(str));
		mxFree(str);
	}
	// struct
	else if (mxIsStruct(matlabVar)) {
		int nfields;

		nfields = mxGetNumberOfFields(matlabVar);
		MLPutFunction(link, "matStruct", 1);
		MLPutFunction(link, "List", nfields);
		for (i=0; i < nfields; ++i) {
			const char *fieldname;

			fieldname = mxGetFieldNameByNumber(matlabVar, i);
			MLPutFunction(link, "Rule", 2);
			MLPutString(link, fieldname);
			toMma(mxGetFieldByNumber(matlabVar, 0, i), link); // TODO support multielement fields
		}
	}
	// cell
	else if (mxIsCell(matlabVar)) {
		int len;

		len = mxGetNumberOfElements(matlabVar);
		MLPutFunction(link, "matCell", 2);
		MLPutFunction(link, "List", len);
		for (i = 0; i < len; ++i) {
			toMma(mxGetCell(matlabVar, i), link);
		}
		MLPutInteger32List(link, mmaDims, depth);
	}
	// unknown or failure; TODO distinguish between unknown and failure
	else
	{
		const char *classname;

		classname = mxGetClassName(matlabVar);
		MLPutFunction(link, "matUnknown", 1);
		MLPutString(link, classname);
	}

	free(mmaDims);
}


void engget(const char* VarName)
{
	mxArray *MxVar;				// MATLAB variable
	bool     SUCCESS = true;	// status flag
    
	if (NULL == Eng)	//if MATLAB not opened
	{
		msg("eng::noMLB");	//message no start
		SUCCESS = false;
		goto epilog;
	}

	if (NULL == (MxVar = engGetVariable(Eng, VarName)))	//get variable
	{
		msg("engGet::erget");
		SUCCESS = false;
		goto epilog;
	}

	/*
	if ( toMma(MxVar, stdlink) ) { // failure
		msg("engGet::ertp");
		SUCCESS = false;
		goto epilog;
	}*/
	toMma(MxVar, stdlink);

epilog:
	// cleanup
	if(NULL != MxVar)
		mxDestroyArray(MxVar);		
	if (! SUCCESS)
		MLPutSymbol(stdlink, "$Failed");
}

