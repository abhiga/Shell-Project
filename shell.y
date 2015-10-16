
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
void yyerror(const char * s);
int yylex();

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

	       Command::_currentSimpleCommand->insertArgument( $1 );
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
		Command::_currentCommand._outFile = $2;
	}
	|
	LESS WORD {
		//printf ("  Yacc: insert input \"%s\"\n", $2);
		Command::_currentCommand._inputFile = $2;
	}
	|
	GREATAMPERSAND WORD {
		Command::_currentCommand._outFile = $2;
		Command::_currentCommand._errFile = strdup($2);
	}
	|
	GREATGREATAMPERSAND WORD {
		Command::_currentCommand._append = 1;
		Command::_currentCommand._outFile = $2;
		Command::_currentCommand._errFile = strdup($2);
	}
	|
	GREATGREAT WORD {
		Command::_currentCommand._append = 1;
		Command::_currentCommand._outFile = $2;
	}
	/* can be empty */ 
	;





%%

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
