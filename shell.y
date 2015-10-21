
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
#include <pwd.h>
	char **array;
	void expandEnv(char*);
	void checkThenInsert(char *);
	void expandTilde(char *);
	void expandWildcardsifNecessary(char *);
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
	if (!(strchr($1, '*') == NULL && strchr($1, '?') == NULL)) {
		expandWildcardsifNecessary($1);
	}

	else
		checkThenInsert($1);
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

void checkThenInsert(char * temp) {
	if(*temp == '~') 
		expandTilde(temp);
	if(*temp == '$')
		expandEnv(temp);
Command::_currentSimpleCommand->insertArgument( temp );
}
void expandTilde(char * temp){
	if ((strcmp(temp, "~") == 0) || (strcmp(temp, "~/") == 0)) 
        strcpy(temp, getpwnam(getenv("USER"))->pw_dir);
    else {
		char newTemp[strlen(temp) + 10];
		strcpy(newTemp, "/homes/");
		char *shiftTemp = temp;
		shiftTemp++;
		strcat(newTemp,shiftTemp);
		strcpy(temp,newTemp);
	} 
} 
void expandWildcard(char* prefix, char* suffix) {
	if (suffix[0] == 0) 
        return;
    char * sub = strchr(suffix, '/');
    char component[1024];
    if (sub != NULL) {
        if ((sub - suffix) < 1) 
            component[0] = '\0';
        else 
            strncpy(component, suffix, sub - suffix);
        
        suffix = sub + 1;
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
		//perror("opendir");
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
	//sort
	for (int i = 0; i < nEntries; i++) {
		for (int j = 0; j < nEntries-1; j++) {
			if (strcmp(array[j], array[j + 1]) > 0) {
                char * tmp = array[j + 1];
                array[j + 1] = array[j];
                array[j] = tmp;
			}
		}
	}
	for (int i = 0; i < nEntries; i++) 
        Command::_currentSimpleCommand->insertArgument(strdup(array[i]));
	closedir(dir);
}
void expandWildcardsifNecessary(char * tmp) {
		char temp[1];
		expandWildcard(temp, tmp);
		free(array);
}
void expandEnv(char* temp) {
	char * tomatch = "\\${.*}";
	regex_t re;
	regmatch_t match;
	int regexbuff = regcomp(&re, tomatch, 0);
	if (regexbuff != 0) {
        perror("regcomp");
        return;
    }
	if(regexec(&re, temp, 1, &match, 0) == 0) {
		char expArg[1024];
		memset(expArg, 0, 1024);
		char * temp2 = expArg;
		//char * temp3 = temp2 + 1;
		int i = 0;
		//int j = 0;
		while(temp[i]!='\0' && i < 1024) {
			
			if (temp[i] != '$') {
				*temp2 = temp [i];
				temp2++;
				i++;
			}
			else {
				char *beg = strchr((char *)(temp + i), '{');
				beg[strlen(beg)-1] = '\0';
				beg++;
				char *out = strdup(beg);
				char * final = getenv(out);
				strcat (expArg, final);
				temp2 = temp2 + strlen(final);
				i = i + strlen(out) + 3;
				//j = strlen(final) + j;
			}
		}
		strcpy(temp,expArg);
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
