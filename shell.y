
/*
 * CS-252 Spring 2013
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%token	<string_val> WORD

%token 	NOTOKEN GREAT NEWLINE LESS GREATAMPERSAND AMPERSAND PIPE GREATGREATAMPERSAND GREATGREAT

%union	{
	char   *string_val;
}

%{

	//#define yylex yylex
#include <stdio.h>
#include <string.h>
#include "command.h"
	char **array;
	void sortArr(char **, int);
	void expandWildcard(char*, char*);
	void yyerror(const char * s);
	int yylex();
	void reset();
	%}

	%%

	goal:	
	commands
	;

commands: 
command
| commands command 
;

command: simple_command
;

simple_command:	
pipe_list iomodifier_list background_optional NEWLINE {
	//printf("   Yacc: Execute command\n");
	Command::_currentCommand.execute();
}
| NEWLINE {
	Command::_currentCommand.clear();
	Command::_currentCommand.prompt();
}
| error NEWLINE { yyerrok; }
;

pipe_list :
pipe_list PIPE command_and_args
|
command_and_args
;

command_and_args:
command_word arg_list {
	Command::_currentCommand.
		insertSimpleCommand( Command::_currentSimpleCommand );
}
;

arg_list:
arg_list argument
| /* can be empty */
;

argument:
WORD {
	//printf("   Yacc: insert argument \"%s\"\n", $1);
	if (strchr($1, '*') == NULL && strchr($1, '?') == NULL) {
		Command::_currentSimpleCommand->insertArgument( $1 );
		
	}

	else {
		char temp[1];
		temp[0] = '\0';
		expandWildcard(temp, $1);
		free(array);
	}
}
;

command_word:
WORD {
	//printf("   Yacc: insert command \"%s\"\n", $1);
	Command::_currentSimpleCommand = new SimpleCommand();
	Command::_currentSimpleCommand->insertArgument( $1 );	
}
;

background_optional:
AMPERSAND {
	Command::_currentCommand._background = 1;
}
|
;

iomodifier_list:
iomodifier_list iomodifier_opt
|
;

iomodifier_opt:
GREAT WORD {
	//printf("   Yacc: insert output \"%s\"\n", $2);
	if (Command::_currentCommand._outFile) {
		yyerror("Ambiguous output redirect");
	}
	Command::_currentCommand._outFile = $2;
}
|
LESS WORD {
	//printf ("  Yacc: insert input \"%s\"\n", $2);
	Command::_currentCommand._inputFile = $2;
}
|
GREATAMPERSAND WORD {
	if (Command::_currentCommand._outFile) {
		yyerror("Ambiguous output redirect");
	}
	Command::_currentCommand._outFile = $2;
	Command::_currentCommand._errFile = strdup($2);
}
|
GREATGREATAMPERSAND WORD {
	if (Command::_currentCommand._outFile) {
		yyerror("Ambiguous output redirect");
	}
	Command::_currentCommand._append = 1;
	Command::_currentCommand._outFile = $2;
	Command::_currentCommand._errFile = strdup($2);
}
|
GREATGREAT WORD {
	if (Command::_currentCommand._outFile) {
		yyerror("Ambiguous output redirect");
	}
	Command::_currentCommand._append = 1;
	Command::_currentCommand._outFile = $2;
}
/* can be empty */ 
;





%%
#include <regex.h>
#include <dirent.h>

void expandWildcard(char* prefix, char* suffix) {
	if (suffix[0] == 0) {
        return;
    }
    char * s = strchr(suffix, '/');
    char component[1024];
    if (s != NULL) {
        if ((s - suffix) < 1) 
            component[0] = '\0';
        else 
            strncpy(component, suffix, s - suffix);
        
        suffix = s + 1;
    } 
	else {
     	strcpy(component, suffix);
        suffix = suffix + strlen(suffix);
    }

    char newPrefix[1024];
    if ((strchr(component, '*') == NULL) && (strchr(component, '?') == NULL)) {
        if (strlen(prefix) == 1 && *prefix == '/') {
            sprintf(newPrefix, "/%s", component);
        } 
		else {
            sprintf(newPrefix, "%s/%s", prefix, component);
        }
        expandWildcard(strdup(newPrefix), strdup(suffix));
        return;
    }
	char * reg = (char *) malloc(2 * strlen(component) + 10);
	char * a = component;
	char * r = reg;
	*r = '^'; r++;
	while (*a) {
		if (*a == '*') { *r='.'; r++; *r='*'; r++; }
		else if (*a == '?') { *r='.'; r++;}
		else if (*a == '.') { *r='\\'; r++; *r='.'; r++;}
		else { *r=*a; r++;}
		a++;
	}
	*r='$'; r++; *r='\0';
	regex_t re;
	int regexbuff = regcomp(&re, reg, REG_EXTENDED | REG_NOSUB);
	if (regexbuff != 0) {
        perror("regcomp");
        return;
    }
	char * dr;
	if (prefix[0] == 0) {
        dr = (char *)malloc(sizeof(char) * 2);
        dr[0] = '.';
        dr[1] = '\0';
    } 
	else {
        dr = strdup(prefix);
    }

	DIR * dir = opendir(dr);
	if (dir == NULL) {
		perror("opendir");
		return;
	}
	regmatch_t match;
	struct dirent * ent;
	int maxEntries = 20;
	int nEntries = 0;
	array = (char **)malloc(maxEntries * sizeof(char*));
	while((ent = readdir(dir))!=NULL) {
		if(regexec(&re, ent -> d_name, 1, &match, 0) == 0) {
			if (strlen(prefix) == 0) {
                sprintf(newPrefix, "%s", strdup(ent->d_name));
            } 
			else if (strlen(prefix) == 1 && *prefix == '/') {
                sprintf(newPrefix, "/%s", strdup(ent->d_name));
            } 
            else {
                sprintf(newPrefix, "%s/%s", prefix, strdup(ent->d_name));
            }
			expandWildcard(strdup(newPrefix), strdup(suffix));
			if (nEntries >= maxEntries) {
                maxEntries = maxEntries + maxEntries;
                array = (char **)realloc(array, maxEntries * sizeof(char *));
            }
			if (*ent->d_name == '.') {
                if (*component == '.') 
                    array[nEntries++] = strdup(ent->d_name);
                
            } 
			else {
                if (strlen(suffix) ==0) 
                    array[nEntries++] = strdup(newPrefix);
			}
		
		}
	}
	for (int i = 0; i < nEntries; i++) {
		for (int j = 0; j < nEntries-1; j++) {
			if (strcmp(array[i], array[i + 1]) > 0) {
                char * tmp = array[i + 1];
                array[i + 1] = array[i];
                array[i] = tmp;
			}
		}
	}
	//sortArr(array, nEntries);
	for (int i = 0; i < nEntries; i++) 
        Command::_currentSimpleCommand->insertArgument(strdup(array[i]));
	closedir(dir);
}
void sortArr(char **&array, int num) {
	for (int i = 0; i < num; i++) {
		for (int j = 0; j < num-1; j++) {
			if (strcmp(array[i], array[i + 1]) > 0) {
                char * tmp = array[i + 1];
                array[i + 1] = array[i];
                array[i] = tmp;
			}
		}
	}
}
	void
yyerror(const char * s)
{
	fprintf(stderr,"%s", s);
}

#if 0
main()
{
	yyparse();
}
#endif
