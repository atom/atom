/**
* Author 	: Mohammed Fawzan
* Problem 	: Guilty
*/

/**
*	I need a chunk of string for given size,
*	Am I making a mistake?  You tell me.
*/

#define NULL 0

char * giveMeSomeMemory ( int size ){
	char * str ;
	if (size > 0)
		str =( char *) malloc ( size );
	if (size == -1)
		return NULL ;
	return ( str );
}
