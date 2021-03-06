
/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 */
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <string.h>
#include <signal.h>

#include "command.h"

SimpleCommand::SimpleCommand()
{
	// Creat available space for 5 arguments
	_numberOfAvailableArguments = 5;
	_numberOfArguments = 0;
	_arguments = (char **) malloc( _numberOfAvailableArguments * sizeof( char * ) );
}

	void
SimpleCommand::insertArgument( char * argument )
{
	if ( _numberOfAvailableArguments == _numberOfArguments  + 1 ) {
		// Double the available space
		_numberOfAvailableArguments *= 2;
		_arguments = (char **) realloc( _arguments,
				_numberOfAvailableArguments * sizeof( char * ) );
	}

	_arguments[ _numberOfArguments ] = argument;

	// Add NULL argument at the end
	_arguments[ _numberOfArguments + 1] = NULL;

	_numberOfArguments++;
}

Command::Command()
{
	// Create available space for one simple command
	_numberOfAvailableSimpleCommands = 1;
	_simpleCommands = (SimpleCommand **)
		malloc( _numberOfSimpleCommands * sizeof( SimpleCommand * ) );

	_numberOfSimpleCommands = 0;
	_outFile = 0;
	_inputFile = 0;
	_errFile = 0;
	_background = 0;
	_append = 0;
}

	void
Command::insertSimpleCommand( SimpleCommand * simpleCommand )
{
	if ( _numberOfAvailableSimpleCommands == _numberOfSimpleCommands ) {
		_numberOfAvailableSimpleCommands *= 2;
		_simpleCommands = (SimpleCommand **) realloc( _simpleCommands,
				_numberOfAvailableSimpleCommands * sizeof( SimpleCommand * ) );
	}

	_simpleCommands[ _numberOfSimpleCommands ] = simpleCommand;
	_numberOfSimpleCommands++;
}

	void
Command:: clear()
{
	for ( int i = 0; i < _numberOfSimpleCommands; i++ ) {
		for ( int j = 0; j < _simpleCommands[ i ]->_numberOfArguments; j ++ ) {
			free ( _simpleCommands[ i ]->_arguments[ j ] );
		}

		free ( _simpleCommands[ i ]->_arguments );
		free ( _simpleCommands[ i ] );
	}

	if ( _outFile ) {
		free( _outFile );
	}

	if ( _inputFile ) {
		free( _inputFile );
	}

	if ( _errFile ) {
		free( _errFile );
	}

	_numberOfSimpleCommands = 0;
	_outFile = 0;
	_inputFile = 0;
	_errFile = 0;
	_background = 0;
}

	void
Command::print()
{
	printf("\n\n");
	printf("              COMMAND TABLE                \n");
	printf("\n");
	printf("  #   Simple Commands\n");
	printf("  --- ----------------------------------------------------------\n");

	for ( int i = 0; i < _numberOfSimpleCommands; i++ ) {
		printf("  %-3d ", i );
		for ( int j = 0; j < _simpleCommands[i]->_numberOfArguments; j++ ) {
			printf("\"%s\" \t", _simpleCommands[i]->_arguments[ j ] );
		}
	}

	printf( "\n\n" );
	printf( "  Output       Input        Error        Background\n" );
	printf( "  ------------ ------------ ------------ ------------\n" );
	printf( "  %-12s %-12s %-12s %-12s\n", _outFile?_outFile:"default",
			_inputFile?_inputFile:"default", _errFile?_errFile:"default",
			_background?"YES":"NO");
	printf( "\n\n" );

}

	void
Command::execute()
{
	// Don't do anything if there are no simple commands
	if ( _numberOfSimpleCommands == 0 ) {
		prompt();
		return;
	}

	if (strcmp(_simpleCommands[0]->_arguments[0], "exit") == 0) {
		printf("Good bye!!\n");
		exit(0);
	}
	if(strcmp(_simpleCommands[0]->_arguments[0], "--debug") == 0) {
		_debug = 1;
		fprintf(stderr,"Be Careful! Entering the shell's debug mode\n");
		prompt();
	}
	if(strcmp(_simpleCommands[0]->_arguments[0], "--normal") == 0) {
		_debug = 0;
		fprintf(stderr,"Reverting to normal mode.\n");
		prompt();
	}
	
	// Print contents of Command data structure
	if (_debug == 1)		
		print();

	// Add execution here
	// For every simple command fork a new process
	// Setup i/o redirection
	// and call exec

	int ret, fdin, fdout;
	// save stdin, stdout & stderr
	int tempin = dup(0);
	int tempout = dup(1);
	int temperr = dup(2);
	if (_inputFile) {
		//open given file for reading
		fdin = open(_inputFile, O_RDONLY);
	}
	else {
		//use default input
		fdin = dup(tempin);
	}
	for (int i = 0; i < _numberOfSimpleCommands; i++) {
		dup2(fdin, 0);
		close(fdin);
		if(i == _numberOfSimpleCommands - 1) {
			if(_outFile) {
				if(!_append) {
					fdout = open(_outFile, O_RDWR | O_CREAT | O_TRUNC, S_IRWXU | S_IRWXG | S_IRWXO);
				}
				else {
					fdout = open(_outFile, O_RDWR | O_CREAT | O_APPEND, S_IRWXU | S_IRWXG | S_IRWXO);
				}
			}
			else {
				fdout = dup(tempout);
			}
			if (_errFile) {
				dup2(fdout, 2);
			}
		}
		else {
			int fdpipe[2];
			pipe(fdpipe);
			fdout = fdpipe[1];
			fdin = fdpipe[0];
		}
		dup2(fdout, 1);

		close(fdout);

		if (strcmp(_simpleCommands[0]->_arguments[0], "setenv") == 0) 
			setenv(_simpleCommands[0]->_arguments[1], _simpleCommands[0]->_arguments[2], 1);
		else if(strcmp(_simpleCommands[0]->_arguments[0], "unsetenv") == 0) 
			unsetenv(_simpleCommands[0]->_arguments[1]);
		else if (strcmp(_simpleCommands[0]->_arguments[0], "cd") == 0) {
			if (_simpleCommands[0]->_arguments[1] == NULL)
				chdir(getenv("HOME"));
			else if (chdir(_simpleCommands[0]->_arguments[1]) < 0) 
				perror("chdir");
		}
		else {
			ret = fork();
			if (ret == 0) {
				execvp(_simpleCommands[i]->_arguments[0], _simpleCommands[i]->_arguments);
				perror("execvp");
				exit(1);
			}
			else if (ret < 0) {
				perror("fork");
				return;
			}
		}


	}
	dup2(tempin, 0);
	dup2(tempout, 1);
	dup2(temperr, 2);
	close(tempin);
	close(tempout);
	close(temperr);
	if (!_background)
		waitpid(ret, NULL, 0);

	// Clear to prepare for next command
	clear();
	// Print new prompt
	prompt();

}

// Shell implementation

	void
Command::prompt()
{
	if (isatty(0)) {	
		printf("myshell>");
	}
	fflush(stdout);
}

Command Command::_currentCommand;
SimpleCommand * Command::_currentSimpleCommand;

int yyparse(void);

extern "C" void avoid_controlc( int sig )
{	
	fprintf(stdout,"\n");
	Command::_currentCommand.clear();
	Command::_currentCommand.prompt();
}
void avoid_zombiep(int sig) {
	while (waitpid((pid_t)(-1), 0, WNOHANG) > 0) {}   
}

main()
{
	signal(SIGINT, avoid_controlc );
	signal(SIGCHLD, avoid_zombiep);
	Command::_currentCommand.prompt();
	yyparse();
}

