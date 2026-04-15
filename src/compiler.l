/* Definition section */
%option yymore
%{
    #include <utf8.c/utf8.h>
    #include "chinese_number.h"
    #include "compiler_util.h"

    #define YY_NO_UNPUT
    #define YY_NO_INPUT

    int yycolumnUtf8, yylengUtf8, yytokenLine = 0;
    utf8_string yytextUtf8;

    static inline void updateNewline() {
        // TODO: Update the line number and column number
        yytokenLine++;
        yycolumnUtf8 = 0;
    }

    /* Calculates UTF-8 character length to update the column counters */
    static inline void processUtf8Char() {
        yytextUtf8 = make_utf8_string(yytext);
        if (yytextUtf8.str) {
            // TODO: Calculate the column number
            yylengUtf8 = utf8_char_count(yytextUtf8);
            yycolumnUtf8 += yylengUtf8;
        }
    }

    /* Appends the next matched token and reverting the column counters to the start of the string */
    static inline void yymore_utf8() {
        yymore();
        if (yytextUtf8.str) {
            // TODO: Reset column
            yycolumnUtf8 -= yylengUtf8;
        }
    }

    #define YY_USER_ACTION \
        processUtf8Char();

    #define PRINT_TOKEN(format, ...) printf("%d:%d: " format "\n", yytokenLine, yycolumnUtf8 - yylengUtf8, __VA_ARGS__)

    /* Extracts string from the current token by specified padding */
    char* trimStringToken(int paddLen) {
        static char cache[100];
        // TODO: Slice the string and copy
        memset(cache, 0, sizeof(cache));
        memcpy(cache, yytext, strlen(yytext)-paddLen);

        return cache;
    }
%}

/* Define regular expression label */
digit ("零")|("一")|("二")

UTF8_BOM "\357\273\277"

ASCII   [\x00-\x7f]
U       [\x80-\xbf]

B2      [\xC2-\xDF]{U}
B3_1    \xE0[\xA0-\xBF]{U}
B3_2    [\xE1-\xEC]{U}{U}
B3_3    \xED[\x80-\x9F]{U}
B3_4    [\xEE-\xEF]{U}{U}
B4_1    \xF0[\x90-\xBF]{U}{U}
B4_2    [\xF1-\xF3]{U}{U}{U}
B4_3    \xF4[\x80-\x8F]{U}{U}

/* ALL UTF-8 https://www.w3.org/2005/03/23-lex-U#charRange
  {ASCII}
| ([\xC2-\xDF] {U})
| ( \xE0       [\xA0-\xBF]{U})
| ([\xE1-\xEC] {U}{U})
| ( \xED       [\x80-\x9F]{U})
| ([\xEE-\xEF] {U}{U})
| ( \xF0       [\x90-\xBF]{U}{U})
| ([\xF1-\xF3] {U}{U}{U})
| ( \xF4       [\x80-\x8F]{U}{U})
*/

ALL_UTF8 {ASCII}|{B2}|{B3_1}|{B3_2}|{B3_3}|{B3_4}|{B4_1}|{B4_2}|{B4_3}

B3_2_EXCLUDE_QUO ([\xE1-\xE2]{U}{U})|(\xE3\x80[\x80-\x8C\x8E-\xBF])|(\xE3[\x81-\xBF]{U})|([\xE4-\xEC]{U}{U})

EXCLUDE_QUO [\x20-\x7E]|{B2}|{B3_1}|{B3_2_EXCLUDE_QUO}|{B3_3}|{B3_4}|{B4_1}|{B4_2}|{B4_3}

%option yylineno
%x IDENT_CON
%x COMMENT

 /* Rules section */
%%

"「「"        { printf("%i:%i: STR_LIT \"", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); BEGIN(COMMENT); }
<COMMENT>"」」"     { printf("\"\n"); BEGIN(INITIAL); }
<COMMENT>\n     { updateNewline(); printf("\n"); }
<COMENT>\t      { printf("\t"); }

"名之曰"     { printf("%i:%i: NAME_IT 名之曰\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1);  }
"注曰"       { printf("%i:%i: COMMENT 注曰\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"今有"       { printf("%i:%i: HERE_ARE 今有\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"今"        { printf("%i:%i: SET 今\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"爻"        { printf("%i:%i: VAR_TYPE 爻\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"。"        {}
"曰"        { printf("%i:%i: SAID 曰\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"陰"        { printf("%i:%i: BOOL_LIT false\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"數"        { printf("%i:%i: VAR_TYPE 數\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"有"        { printf("%i:%i: HERE_IS_A 有\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }


"「"        { BEGIN(IDENT_CON); }
<IDENT_CON>"」"    { BEGIN(INITIAL); PRINT_TOKEN("IDENT '%s'", trimStringToken(3)); }
<IDENT_CON>\r?\n    { yymore_utf8(); }
<IDENT_CON>{EXCLUDE_QUO}+    { yymore_utf8(); }

{digit}+·{digit}+  {
    ScientificNotation sciOut;
    if (!chineseToArabic(yytext, &sciOut)){
        printf("%i:%i: NUMBER_LIT %s\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1, sciToStr(&sciOut));
    }
}

{digit}+ { 
    /* use chinese_number.h to parse the number */ 
    ScientificNotation sciOut;
    if (!chineseToArabic(yytext, &sciOut)){
        printf("%i:%i: NUMBER_LIT %i\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1, sciToInt32(&sciOut));
    }
}

[ \t]+      {}
\r?\n       { updateNewline(); }
{UTF8_BOM}  { updateNewline(); /* Skip UTF-8 BOM */ }

<<EOF>>     { yyterminate(); }

{ALL_UTF8} { PRINT_TOKEN("UNKNOWN CHAR %s", yytext); }
. { PRINT_TOKEN("UNKNOWN CHAR %s", yytext); }

%%
/*  C Code section */
int yywrap(void) {
    return 1;
}