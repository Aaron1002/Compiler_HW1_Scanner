/* Definition section */
%option yymore
%{
    #include <utf8.c/utf8.h>
    #include "chinese_number.h"
    #include "compiler_util.h"

    #define YY_NO_UNPUT
    #define YY_NO_INPUT

    int yycolumnUtf8, yylengUtf8 = 0;
    int yytokenLine = 1;
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

    #define PRINT_TOKEN(format, ...) printf("%d:%d: " format "\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1, __VA_ARGS__)

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
digit ("零")|("一")|("二")|("兩")|("三")|("四")|("五")|("六")|("七")|("八")|("九")|("十")|("百")|("千")

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
<COMMENT>{EXCLUDE_QUO}+    { printf("%s", yytext); }

"乃行是術曰"    { PRINT_TOKEN("FUNC_BEGIN %s", yytext); }
"所餘幾何"  { printf("%i:%i: EXP_MATH_OP %%\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"中有陽乎"  { printf("%i:%i: EXP_LOGIC ||\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); } 
"中無陰乎"  { printf("%i:%i: EXP_LOGIC &&\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"欲行是術"  { PRINT_TOKEN("TO_PERFORM_FUNC %s", yytext); }
"名之曰"    { PRINT_TOKEN("NAME_IT %s", yytext); }
"恆為是"    { PRINT_TOKEN("WHILE_TRUE %s", yytext); }
"不小於"    { printf("%i:%i: EXP_LOGIC >=\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"必先得"    { PRINT_TOKEN("REQUIRE_ARGS %s", yytext); }
"之術也"    { PRINT_TOKEN("FUNC_END %s", yytext); }
"注曰"      { PRINT_TOKEN("COMMENT %s", yytext); }
"今有"      { PRINT_TOKEN("HERE_ARE %s", yytext); }
"昔之"      { PRINT_TOKEN("PAST %s", yytext); }
"是矣"      { PRINT_TOKEN("IS_THUS %s", yytext); }
"吾有"      { PRINT_TOKEN("HERE_ARE %s", yytext); }
"書之"      { PRINT_TOKEN("PRINT %s", yytext); }
"大於"      { printf("%i:%i: EXP_LOGIC >\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"等於"      { printf("%i:%i: EXP_LOGIC ==\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"若非"      { PRINT_TOKEN("ELSE %s", yytext); }
"或若"      { PRINT_TOKEN("ELSE_IF %s", yytext); }
"乃止"      { PRINT_TOKEN("BREAK %s", yytext); }
"云云"      { PRINT_TOKEN("END %s", yytext); }
"為是"      { PRINT_TOKEN("FOR %s", yytext); }
"之長"      { PRINT_TOKEN("LENGTH %s", yytext); }
"乃得"      { PRINT_TOKEN("RETURN %s", yytext); }
"是謂"      { PRINT_TOKEN("FUNC_END_FOR %s", yytext); }
"小於"      { printf("%i:%i: EXP_LOGIC <\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"批曰"      { PRINT_TOKEN("COMMENT %s", yytext); }
"今"        { PRINT_TOKEN("SET %s", yytext); }
"爻"        { PRINT_TOKEN("VAR_TYPE %s", yytext); }
"。"         {}
"曰"        { PRINT_TOKEN("SAID %s", yytext); }
"陰"        { printf("%i:%i: BOOL_LIT false\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"陽"        { printf("%i:%i: BOOL_LIT true\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"數"        { PRINT_TOKEN("VAR_TYPE %s", yytext); }
"有"        { PRINT_TOKEN("HERE_IS_A %s", yytext); }
"言"        { PRINT_TOKEN("VAR_TYPE %s", yytext); }
"者"        { PRINT_TOKEN("TOPIC %s", yytext); }
"元"        { PRINT_TOKEN("VAR_TYPE %s", yytext); }
"加"        { printf("%i:%i: EXP_MATH +\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"於"        { printf("%i:%i: <-\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"減"        { printf("%i:%i: EXP_MATH -\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"以"        { printf("%i:%i: ->\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"乘"        { printf("%i:%i: EXP_MATH *\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"除"        { printf("%i:%i: EXP_MATH /\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1); }
"其"        { PRINT_TOKEN("ITS %s", yytext); }
"若"        { PRINT_TOKEN("IF %s", yytext); }
"也"        { PRINT_TOKEN("END %s", yytext); }
"夫"        { PRINT_TOKEN("THOSE %s", yytext); }
"遍"        { PRINT_TOKEN("TIMES %s", yytext); }
"之"        { PRINT_TOKEN("INDEX %s", yytext); }
"列"        { PRINT_TOKEN("VAR_TYPE %s", yytext); }
"充"        { PRINT_TOKEN("PUSH %s", yytext); }
"術"        { PRINT_TOKEN("VAR_TYPE_FUNC %s", yytext); }
"施"        { PRINT_TOKEN("CALL %s", yytext); }
"取"        { PRINT_TOKEN("TAKE %s", yytext); }
"矣"        { PRINT_TOKEN("END %s", yytext); }

"「"        { BEGIN(IDENT_CON); }
<IDENT_CON>"」"    { BEGIN(INITIAL); printf("%d:%d: IDENT '%s'\n", yytokenLine, yycolumnUtf8 - yylengUtf8, trimStringToken(3)); }
<IDENT_CON>\r?\n    { yymore_utf8(); }
<IDENT_CON>{EXCLUDE_QUO}+    { yymore_utf8(); }

{digit}+·"零"  {
    ScientificNotation sciOut;
    if (!chineseToArabic(yytext, &sciOut)){
        printf("%i:%i: NUMBER_LIT %i\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1, sciToInt32(&sciOut));
    }
}

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
{UTF8_BOM}  { yycolumnUtf8 -= yylengUtf8; /* Skip UTF-8 BOM */ }

<<EOF>>     { yyterminate(); }

{ALL_UTF8} { PRINT_TOKEN("UNKNOWN CHAR %s", yytext); }
. { PRINT_TOKEN("UNKNOWN CHAR %s", yytext); }

%%
/*  C Code section */
int yywrap(void) {
    return 1;
}