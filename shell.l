
/*
 *
 * CS-252 Fall 2013
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <string.h>
#include "y.tab.h"

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
    unput(c);
}

%}

%%

\n 	{
		return NEWLINE;
	}

[ \t] 	{
		/* Discard spaces and tabs */
     	}

"|"		{
			return PIPE;
		}

"&"		{
		return AMPERSAND;
		}

">>&"   {
		return GREATGREATAMPERSAND;
		}

">>"	{
		return GREATGREAT;
		}

">&"	{
		return GREATAMPERSAND;
		}

">" 	{
		return GREAT;
		}

"<"		{
		return LESS;
		}

\"[^\n\"]*\"    {
            yylval.string_val = strndup(yytext + 1, strlen(yytext) - 2);
            return WORD;
        }

[^ |<>&\t\n]*[\\][^ \t\n]* {
            yylval.string_val = strdup(yytext);
			return WORD;
		}

\`[^\n`]*\`      {
            yylval.string_val = strndup(yytext + 1, strlen(yytext) - 2);
            //return SUBSHELL;
        }   

[^ |<>&\t\n][^ |<>&\t\n]*  {
		/* Assume that file names have only alpha chars */
		yylval.string_val = strdup(yytext);
		return WORD;
	}

