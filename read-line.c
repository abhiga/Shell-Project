/*
 * CS354: Operating Systems. 
 * Purdue University
 * Example that shows how to read one line with simple editing
 * using raw terminal.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <termios.h>

#define MAX_BUFFER_LINE 2048

// Buffer where line is stored
int line_length;;
char line_buffer[MAX_BUFFER_LINE];
int cursor_pos = 0;
// Simple history array
// This history does not change. 
// Yours have to be updated.
int history_length = 0;
int history_index = 0;
char **history;

void read_line_print_usage()
{
	char * usage = "\n"
		" ctrl-?       Print usage\n"
		" Backspace    Deletes last character\n"
		" up arrow     See last command in the history\n";

	write(1, usage, strlen(usage));
}

/* 
 * Input a line with some basic editing.
 */
char * read_line() {

	struct termios orig_attr;
	tcgetattr(0,&orig_attr);
	// Set terminal in raw mode
	tty_raw_mode();

	line_length = 0;
	cursor_pos = 0;
	// Read one line until enter is typed
	while (1) {

		// Read one character in raw mode.
		char ch;
		read(0, &ch, 1);

		if (ch>=32 && ch!= 127) {
			// It is a printable character. 

			// Do echo
			int i;
			for (i = line_length - 1; i >= cursor_pos; i--){
				line_buffer[i+1] = line_buffer[i];
				//line_buffer[i+2] = '\0';
			}
			line_buffer[cursor_pos] = ch; 
			line_length++;
			if (line_length==MAX_BUFFER_LINE-2) break; 
			for (i = cursor_pos; i < line_length; i++) 
				write(1,&line_buffer[i],1);
			ch = 8;
			for (i = cursor_pos + 1; i < line_length; i++)
				write(1,&ch,1);

			// If max number of character reached return.

			// add char to buffer.
			cursor_pos++;
		}
		else if (ch == 1) {	
			while(cursor_pos) {
				ch = 27;
                write(1,&ch,1);
                ch = 91;
                write(1,&ch,1);
                ch = 68;
                write(1,&ch,1);
				cursor_pos--;
            }
		}
		else if (ch == 4) {
			if(cursor_pos == line_length)
				continue;
			int i;
			for (i = cursor_pos + 1; i < line_length; i++) 
				line_buffer[i - 1] = line_buffer[i];
			line_length--;
			for (i = cursor_pos; i < line_length; i++)
				write(1,&line_buffer[i],1);
			ch = 32;
			write(1,&ch,1);
			ch = 8;
			write(1,&ch,1);
			for(i = cursor_pos; i < line_length; i++) 
				write(1,&ch,1);
		}
		else if (ch == 5) {
			while(cursor_pos < line_length) {
				ch = 27;
                write(1,&ch,1);
                ch = 91;
                write(1,&ch,1);
                ch = 67;
                write(1,&ch,1);
				cursor_pos++;
            }
		}
		else if (ch==10) {
			// <Enter> was typed. Return line

			// Print newline
			if (history_length == 0) {
				history = malloc(50 * sizeof(char*));
			}
			history[history_length] = malloc((MAX_BUFFER_LINE) * sizeof(char));
			strncpy(history[history_length], line_buffer, line_length);
			history[history_length][line_length] = '\0';
			//char *p = strdup (history[history_length]);
			//write(1,p,strlen(p));
			//strncpy(history[history_length], line_buffer, line_length);
			history_length++;			
			write(1,&ch,1);
			break;
		}
		else if (ch == 31) {
			// ctrl-?
			read_line_print_usage();
			line_buffer[0]=0;
			break;
		}
		else if (ch == 8 || ch == 127) {
			// <backspace> was typed. Remove previous character read.

			// Go back one character
			if(cursor_pos==0 || line_length==0)
				continue;
			int i;
			for(i = cursor_pos; i < line_length; i++) {
				line_buffer[i - 1] = line_buffer[i];		
			}
			ch = 8;
			write(1,&ch,1); 

			// Write a space to erase the last character read
			for (i = cursor_pos - 1; i < line_length - 1; i++) {
				ch = line_buffer[i];
				write(1, &ch, 1);
			}
			ch = ' ';
			write(1,&ch,1);

			// Go back one character
			ch = 8;
			write(1,&ch,1);
			for (i = cursor_pos; i < line_length; i++) {
				write(1, &ch, 1);
			}
			// Remove one character from buffer
			cursor_pos--;
			line_length--;
		}
		else if (ch==27) {
			// Escape sequence. Read two chars more
			//
			// HINT: Use the program "keyboard-example" to
			// see the ascii code for the different chars typed.
			//
			char ch1; 
			char ch2;
			read(0, &ch1, 1);
			read(0, &ch2, 1);
			if (ch1 == 91) {
				if (ch2 == 68) {
					//left arrow key
					//write(1, "left arrow\n", strlen("left arrow\n"));
					if (cursor_pos <= 0){
					}
					else {					
						ch = 8;
						write(1, &ch, 1);
						cursor_pos--;
					}
				}
				if (ch2 == 67) {
					//right arrow key
					if(cursor_pos >= line_length) {
					}
					else {
						ch = line_buffer[cursor_pos++];
						write (1, &ch, 1);
					}
				}
				if (ch2 == 66) {
					//down arrow key
				int i;
                for (i =0; i < line_length; i++) {
                    ch = 8;
                    write(1,&ch,1);
                }

                for (i =0; i < line_length; i++) {
                    ch = ' ';
                    write(1,&ch,1);
                }

                for (i =0; i < line_length; i++) {
                    ch = 8;
                    write(1,&ch,1);
                }
                
                if (history_index > 1) {
                    history_index--;                    
                    strcpy(line_buffer, history[history_length - history_index]);
                }
                else {
                    strcpy(line_buffer, "");
                }

                line_length = strlen(line_buffer);
				cursor_pos = line_length;

                write(1, line_buffer, line_length);
                    
				}
				if (ch2==65) {
					// Up arrow. Print next line in history.

					// Erase old line
					// Print backspaces
					if(history_length == 0)
						continue;
					if (history_length == history_index)
						continue;
					int i = 0;
					for (i =0; i < line_length; i++) {
						ch = 8;
						write(1,&ch,1);
					}

					// Print spaces on top
					for (i =0; i < line_length; i++) {
						ch = ' ';
						write(1,&ch,1);
					}

					// Print backspaces
					for (i =0; i < line_length; i++) {
						ch = 8;
						write(1,&ch,1);
					}	
					int history_diff = history_length - history_index;
					if (history_diff > 0)
						history_index++;
						

					// Copy line from history
					strcpy(line_buffer, history[history_diff - 1]);
					line_length = strlen(line_buffer);
					//history_index=(history_index+1)%history_length;
					cursor_pos = line_length;
					// echo line
					write(1, line_buffer, line_length);
				} 
			}

		}

	}

	// Add eol and null char at the end of string
	line_buffer[line_length]=10;
	line_length++;
	line_buffer[line_length]=0;
	tcsetattr(0,TCSANOW,&orig_attr);
	return line_buffer;
}

