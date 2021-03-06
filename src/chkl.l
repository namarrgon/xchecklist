%{

  #include <stdlib.h>
  #include <unistd.h>
  #include <string.h>
  //#include <stdbool.h>
  #include "chkl_parser.h"
  #include "chkl_yacc.h"
  #include "utils.h"

  typedef enum {STATE_CMD, STATE_CDEF, STATE_DESC, STATE_DREF, STATE_EXPR} t_state;
  static t_state state = STATE_CMD;
  static bool open_paren = false;
  static bool is_colour_def = false;
  static bool is_colour_desc = false;
  static bool is_void = false;
  static bool is_checklist = false;
  static bool dref_still = false;
%}
%option noyywrap
%option nounput
%option noinput
%option nodefault
%option warn

%x DESC NUM DREF CDESC CDEF VOID CVOID CL

EOL                     (\r|\n|\n\r|\r\n)
CL_STRING               [^\n\r:]+
STRING                  [^\n\r:|]+
VOID_STRING             [^\n\r|]+
COLOURED_STRING         [^\n\r:|\\]+
COLOURED_VOID_STRING    [^\n\r|\\]+
DATAREF                 [^\n\r:|\[\]\(\)&]+
COLON                   :
LBRACKET                \[
RBRACKET                \]
LPAREN                  \(
RPAREN                  \)
POW                     \*\*
PLUS                    \+
MINUS                   \-
MUL                     \*
DIV                     \/
ABS_DIF                 ><
NEQ                     !
EQ                      =
LT                      <
GT                      >
PIPE                    \|
OR                      \|\|
POS_DIF                 \+>
NEG_DIF                 -<
DOT                     \.
AND                     &&
NUMBER                  [0-9]
SIGN                    [+-]

CONSTANT                [+-]?[0-9]*\.?[0-9]*[eE]?[+-]?[0-9]*

BOM_UTF8                \xef\xbb\xbf
SILENCER                @

%%
{BOM_UTF8}                   {}
{SILENCER}                   {return(TOKEN_SILENCE);}
sw_checklist                 {is_checklist = true; return(TOKEN_CHECKLIST);}
sw_item                      {return(TOKEN_ITEM);}
sw_iteminfo                  {return(TOKEN_ITEMINFO);}
sw_itemvoid                  {is_void = true; return(TOKEN_ITEMVOID);}
sw_show                      {state = STATE_DESC; return(TOKEN_SHOW);}
sw_rcolsize                  {return(TOKEN_RCOLSIZE);}
sw_remark                    {return(TOKEN_REMARK);}
sw_continue[[:blank:]]*      {return(TOKEN_CONTINUE);}
sw_define_colour             {is_colour_def = true; return(TOKEN_COLOUR_DEF);}
sw_item_c                    {is_colour_desc = true; return(TOKEN_ITEM);}
sw_itemvoid_c                {is_colour_desc = true; is_void = true; return(TOKEN_ITEMVOID);}


<CL>{CL_STRING}              {
                               chkllval.str=strdup(yytext);
                               return(TOKEN_STRING);
                             };
<CVOID>{COLOURED_VOID_STRING} {
                               chkllval.str=strdup(yytext);
                               return(TOKEN_STRING);
                             }
<CVOID>\\{COLOURED_VOID_STRING}\\ {
                               size_t len = strlen(yytext);
                               chkllval.str=strdup(yytext + 1);
                               chkllval.str[len - 2] = '\0';
                               return(TOKEN_COLOUR_NAME);
                             }
<CDESC,CVOID>\\\\            {return(TOKEN_BACKSLASH);}
<CDESC>{COLOURED_STRING} {
                               chkllval.str=strdup(yytext);
                               return(TOKEN_STRING);
                             }
<CDESC>\\{COLOURED_STRING}\\ {
                               size_t len = strlen(yytext);
                               chkllval.str=strdup(yytext + 1);
                               chkllval.str[len - 2] = '\0';
                               return(TOKEN_COLOUR_NAME);
                             }
<*>{COLON}                   {
                               //if(!open_paren){
                                 //fprintf(stderr, ":\n");
                                 if(is_checklist){
                                   BEGIN(CL);
                                   return(TOKEN_COLON);
                                 }
                                 if(is_void){
                                   if(is_colour_desc){
                                     BEGIN(CVOID);
                                   }else{
                                     BEGIN(VOID);
                                   }
                                   return(TOKEN_COLON);
                                 }
                                 switch(state){
                                   case STATE_CMD:
                                     if(is_colour_desc){
                                       BEGIN(CDESC);
                                       //fprintf(stderr, "  STATE -> CDESC\n");
                                       state = STATE_DESC;
                                     }else if(is_colour_def){
                                       BEGIN(CDEF);
                                       //fprintf(stderr, "  STATE -> CDEF\n");
                                       state = STATE_CDEF;
                                     }else{
                                       BEGIN(DESC);
                                       //fprintf(stderr, "  STATE -> DESC\n");
                                       state = STATE_DESC;
                                     }
                                     break;
                                   case STATE_CDEF:
                                     BEGIN(NUM);
                                     state = STATE_EXPR;
                                     //fprintf(stderr, "    STATE -> EXPR\n");
                                     break;  
                                   case STATE_DESC:
                                     BEGIN(DREF);
                                     state = STATE_DREF;
                                     //fprintf(stderr, "    STATE -> DREF\n");
                                     break;
                                   case STATE_DREF:
                                     BEGIN(NUM);
                                     state = STATE_EXPR;
                                     dref_still = open_paren;
                                     //fprintf(stderr, "      STATE -> EXPR\n");
                                     break;
                                   case STATE_EXPR:
                                     break;
                                 }
                               //}
                               return(TOKEN_COLON);
                             }

<NUM>{NEQ}                   {return(TOKEN_NE);}
<NUM>!=                      {return(TOKEN_NE);}
<NUM>{LT}{EQ}                {return(TOKEN_LE);}
<NUM>{GT}{EQ}                {return(TOKEN_GE);}
<NUM>{EQ}                    {return(TOKEN_EQ);}
<NUM>==                      {return(TOKEN_EQ);}
<NUM>{LT}                    {return(TOKEN_LT);}
<NUM>{GT}                    {return(TOKEN_GT);}
<NUM>{POS_DIF}               {return(TOKEN_POS_DIF);}
<NUM>{NEG_DIF}               {return(TOKEN_NEG_DIF);}
<NUM>{ABS_DIF}               {return(TOKEN_ABS_DIF);}

<NUM>{PLUS}                  {return(TOKEN_PLUS);}
<NUM>{MINUS}                 {return(TOKEN_MINUS);}
<NUM>{MUL}                   {return(TOKEN_MUL);}
<NUM>{DIV}                   {return(TOKEN_DIV);}
<NUM>{POW}                   {return(TOKEN_POW);}
<NUM>\{[^}\r\n]+\}           {
                              //skip opening brace, don't include the closing one
                              size_t len = strlen(yytext);
                              chkllval.str = strdup(yytext + 1);
                              chkllval.str[len - 2] = '\0';
                              return(TOKEN_DREF);
                             }
<DREF>{SIGN}?{NUMBER}+       {
                               chkllval.str=strdup(yytext);
                               return(TOKEN_NUMBER);
                             }
<DREF>{SIGN}?{NUMBER}*{DOT}{NUMBER}* {
                               chkllval.str=strdup(yytext);
                               return(TOKEN_NUMBER);
                             }
<DREF>{SIGN}?{NUMBER}+[eE]{SIGN}?{NUMBER}+ {
                               chkllval.str=strdup(yytext);
                               return(TOKEN_NUMBER);
                             }
<DREF>{SIGN}?{NUMBER}*{DOT}{NUMBER}+[eE][+-]?{NUMBER}+ {
                               chkllval.str=strdup(yytext);
                               return(TOKEN_NUMBER);
                             }
<NUM,DREF>{NUMBER}+          {
                               chkllval.str=strdup(yytext);
                               return(TOKEN_NUMBER);
                             }
<NUM,DREF>{NUMBER}*{DOT}{NUMBER}* {
                               chkllval.str=strdup(yytext);
                               return(TOKEN_NUMBER);
                             }
<NUM,DREF>{NUMBER}+[eE]{SIGN}?{NUMBER}+ {
                               chkllval.str=strdup(yytext);
                               return(TOKEN_NUMBER);
                             }
<NUM,DREF>{NUMBER}*{DOT}{NUMBER}+[eE][+-]?{NUMBER}+ {
                               chkllval.str=strdup(yytext);
                               return(TOKEN_NUMBER);
                             }
<NUM>[a-zA-Z][a-zA-Z0-9_]+   {
                               chkllval.str = strdup(yytext);
                               //fprintf(stderr, "\nNSTRING:'%s'\n", yytext);
                               return(TOKEN_STRING);
                             }
<NUM>\(double\)              {return(TOKEN_TO_DOUBLE);}
<NUM>\(float\)               {return(TOKEN_TO_FLOAT);}
<NUM>\(int\)                 {return(TOKEN_TO_INT);}
<NUM>,                       {return(TOKEN_COMA);}

<*>{PIPE}                    {return(TOKEN_PIPE);}
<DREF,NUM>\|\|               {return(TOKEN_OR);}
<DREF,NUM>&&                 {return(TOKEN_AND);}
<DREF>{LBRACKET}             {return(TOKEN_LEFT_BRACKET);}
<DREF>{RBRACKET}             {return(TOKEN_RIGHT_BRACKET);}
<DREF,NUM>{LPAREN}           {open_paren = true; return(TOKEN_LEFT_PARENTHESIS);}
<DREF,NUM>{RPAREN}           {
                               open_paren = false;
                               if(dref_still){
                                 state = STATE_DREF;
                                 BEGIN(DREF);
                               }
                               return(TOKEN_RIGHT_PARENTHESIS);
                             }
<*>#[^\r\n]*                 /*eat comments*/
<*>{EOL}                     {
                               BEGIN(INITIAL);
                               state = STATE_CMD;
                               //fprintf(stderr, "STATE -> CMD\n");
                               open_paren = false;
                               is_colour_def = false;
                               is_colour_desc = false;
                               is_void = false;
                               dref_still = false;
                               is_checklist = false;
                               ++chkllineno;
                               //fprintf(stderr, ">>>>>>>>>>Initial!\n");
                             }
<*>[[:blank:]]+              /*eat whitespaces*/
<VOID>{VOID_STRING}          {
                               chkllval.str=strdup(yytext);
                               //fprintf(stderr, "\nSTRING:'%s'\n", yytext);
                               return(TOKEN_STRING);
                             }
<DESC,CDEF>{STRING}          {
                               chkllval.str=strdup(yytext);
                               //fprintf(stderr, "\nSTRING:'%s'\n", yytext);
                               return(TOKEN_STRING);
                             }
<DREF>{DATAREF}              {
                               chkllval.str=strdup(yytext);
                               //fprintf(stderr, "\nDSTRING:'%s'\n", yytext);
                               return(TOKEN_STRING);
                             }
<*>.                         {
                               xcDebug("XChecklist: Unmatched character '%s' at line %d!\n",
                                 chkltext, chkllineno);
                             }
%%

