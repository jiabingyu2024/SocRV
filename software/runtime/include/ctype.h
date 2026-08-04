#ifndef SOCRV_MINILIBC_CTYPE_H
#define SOCRV_MINILIBC_CTYPE_H

static inline int isdigit(int character)
{
    return character >= '0' && character <= '9';
}

static inline int isxdigit(int character)
{
    return isdigit(character) ||
           (character >= 'a' && character <= 'f') ||
           (character >= 'A' && character <= 'F');
}

static inline int tolower(int character)
{
    if (character >= 'A' && character <= 'Z') {
        return character + ('a' - 'A');
    }
    return character;
}

#endif
